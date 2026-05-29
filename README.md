<div align="center">

# 🖥️ UART · FIFO · Stopwatch · Watch
### FPGA 설계 프로젝트 | Verilog | Basys3

[![Language](https://img.shields.io/badge/Language-Verilog-blue?style=flat-square)]()
[![Board](https://img.shields.io/badge/Board-Basys3%20xc7a35t-green?style=flat-square)]()
[![Tool](https://img.shields.io/badge/Tool-Vivado%202023.1-orange?style=flat-square)]()

온디바이스AI 시스템 반도체 설계 1기 | 송주연 | 대한상공회의소 서울기술교육센터

</div>

---

## 📋 목차

- [프로젝트 개요](#-프로젝트-개요)
- [시스템 구성](#-시스템-구성)
- [입출력 소자](#-입출력-소자)
- [모듈 설명](#-모듈-설명)
  - [UART / FIFO](#uart--fifo)
  - [Stopwatch & Watch](#stopwatch--watch)
- [시뮬레이션](#-시뮬레이션)
- [Trouble Shooting](#-trouble-shooting)
- [검증 (UVM-style Testbench)](#-검증-uvm-style-testbench)
- [고찰 및 개선할 점](#-고찰-및-개선할-점)

---

## 🎯 프로젝트 개요

> PC와 FPGA 간 UART 양방향 통신 프로토콜 설계, FIFO 구조의 데이터 버퍼 설계,  
> Basys3 보드에서 버튼·스위치·PC 키 입력으로 동작하고 FND에 출력하는 Stopwatch / Watch 구현.

| 항목 | 내용 |
|------|------|
| **언어** | Verilog |
| **보드** | Digilent Basys3 (xc7a35t) |
| **툴** | Vivado 2023.1 |
| **통신** | UART Full Duplex (baud rate 9600bps, x16 Over Sampling) |
| **버퍼** | FIFO (RX / TX 각각) |
| **외부 HW** | SR04 초음파 거리 센서, DHT11 온습도 센서 |

---

## 🗂️ 시스템 구성

```
                    ┌──────────────────────────────────────────────────────┐
                    │                     uart_top                         │
                    │                                                      │
 [PC]               │  uart_rx ──► FIFO(rx) ──► ascii_decoder             │
  │  uart_rx_pin ──►│                               │ o_r/o_l/o_u/o_d     │
  │                 │                               ▼                     │
  │                 │                    top_stopwatch_watch               │
  │                 │                               │ FND data             │
  │                 │                               ▼                     │
  │  uart_tx_pin ◄──│  uart_tx ◄── FIFO(tx) ◄── ascii_sender             │
  │                 │                     ▲  i_send ('s' key)             │
  └─────────────────┴──────────────────────────────────────────────────────┘
                                          baud_tick (9600 x16)
```

---

## 🎛️ 입출력 소자

### Switches

| sw | 0 | 1 |
|----|---|---|
| **sw[0]** | Up count | Down count |
| **sw[1]** | Watch | Stopwatch |
| **sw[2]** | sec.msec 표시 | hour.min 표시 |
| **sw[3]** | SR04 / Watch 모드 | DHT11 / Stopwatch 모드 |

### Buttons & UART Key Input

| 동작 | Button | UART Key |
|------|--------|----------|
| **Stopwatch** Reset | `reset` | — |
| **Stopwatch** Clear | `btn_l` | `'l'` |
| **Stopwatch** Run/Stop | `btn_r` | `'r'` |
| **Watch** 왼쪽 자리 선택 | `btn_l` | `'l'` |
| **Watch** 오른쪽 자리 선택 | `btn_r` | `'r'` |
| **Watch** 값 증가 | `btn_u` | `'u'` |
| **Watch** 값 감소 | `btn_d` | `'d'` |
| **현재 FND 값 PC 전송** | — | `'s'` |

---

## 🔩 모듈 설명

### UART / FIFO

---

#### `baud_tick`
9600bps의 **16배속 Over Sampling tick** 생성.  
TX·RX 간 Baud Rate 오차로 인한 데이터 손실을 줄이기 위해 1 Baud Rate를 16 tick으로 분할, RX가 비트의 중앙에서 값을 수신하도록 함.

---

#### `uart_rx`
UART 수신 담당. 1bit 직렬 입력을 **8bit 병렬 데이터** `rx_data`로 변환.

```
Idle ──(b_tick=1 & RX=0)──► Start
  ──(b_tick_cnt=7)──► DATA ──(bit_cnt<7)── 루프
  ──(bit_cnt=7 & b_tick_cnt=15)──► Stop
  ──► Output(rx_done 1clk 펄스) ──► Idle
```

- `rx_done` 발생 시점: STOP → IDLE 전환 직전 (8비트 수신 완료)
- `rx_done` 펄스로 FIFO push 및 ascii_decoder tick 생성 트리거

---

#### `uart_tx`
UART 송신 담당. FIFO TX에서 꺼낸 8bit 데이터를 1bit씩 직렬 전송.

```
Idle ──(tx_start=1)──► Start(0)
  ──► DATA(bit_cnt 0→7) ──► Stop(1) ──► Idle
```

- `tx_busy`: 전송 중 High 유지
- `tx_done`: 전송 완료 1clk 펄스

---

#### `fifo_rx` / `fifo_tx`
UART RX와 소비자(ascii_decoder), 생산자(ascii_sender)와 UART TX 사이의 **데이터 버퍼**.

| 신호 | 역할 |
|------|------|
| `push` / `push_data` | 데이터 FIFO에 저장 |
| `pop` / `pop_data` | FIFO에서 데이터 출력 (다음 사이클 반영) |
| `empty` | 비어있으면 pop 차단 |
| `full` | 가득 차면 push 차단 |

> **FIFO를 쓰는 이유**: UART RX는 수신 즉시 처리하지 않으면 다음 바이트에 덮어씌워짐. FIFO가 생산자·소비자의 속도·타이밍 차이를 완충해 양쪽이 독립적으로 동작 가능.

---

#### `ascii_decoder`
수신된 `rx_data`의 ASCII Code를 해석해 Stopwatch / Watch 동작 tick 신호 생성.

| ASCII Key | 출력 신호 | 동작 |
|-----------|----------|------|
| `'r'` | `o_r` | btn_r (Run/Stop, 오른쪽 선택) |
| `'l'` | `o_l` | btn_l (Clear, 왼쪽 선택) |
| `'u'` | `o_u` | btn_u (값 증가) |
| `'d'` | `o_d` | btn_d (값 감소) |

- `rx_done` 펄스를 이용해 tick 생성 (STOP→IDLE 전환 시점)

---

#### `ascii_sender`
PC에서 `'s'` 수신 시 `i_send` 발생 → FND 표시 데이터를 포맷에 맞게 변환해 15글자 FIFO TX로 전송.

```
IDLE ──(i_send=1)──► SEND(글자 순차 push)
  ──(fifo full)──► WAIT ──(not full)──► SEND 재개
  ──(15글자 완료 & not full)──► IDLE
```

출력 포맷: `Stopwatch시간 / Watch시간 / SR04거리 / DHT11온습도`

---

### Stopwatch & Watch

---

#### `btn_debounce`
버튼 채터링 제거, 입력 신호를 **1 clock 펄스**로 변환.

- 100kHz tick 기반 8-tap Shift Register 필터링
- 입력 최소 80us 이상 유지 시 `debounce = 1`
- `debounce & (~edge_reg)` → rising edge 1clk만 출력

---

#### `stopwatch_control_unit` — FSM (Moore Machine)

| State | `o_run_stop` | `o_clear` | 전이 조건 |
|-------|:-----------:|:--------:|----------|
| **STOP** | 0 | 0 | `i_run_stop=1` → RUN \| `i_clear=1` → CLEAR |
| **RUN** | 1 | 0 | `i_run_stop=1` → STOP (CLEAR 비활성) |
| **CLEAR** | 0 | 1 | `i_run_stop=1` → RUN |

---

#### `watch_control_unit` — FSM (Moore Machine)

| State | `o_up` | `o_down` | 전이 조건 |
|-------|:------:|:-------:|----------|
| **NORMAL** | 0 | 0 | `i_up=1` → UP \| `i_down=1` → DOWN |
| **UP** | 1 | 0 | `i_up=0` → NORMAL (1clk 유지) |
| **DOWN** | 0 | 1 | `i_down=0` → NORMAL (1clk 유지) |

---

#### `watch_modify_sel` — FSM (Moore Machine)

Watch 시간 수정 자리 선택.

| State | `sel_mod_btn` | 수정 대상 | 전이 조건 |
|-------|:------------:|---------|----------|
| **LEFT** | 1 | hour, sec | `btn_r` → RIGHT |
| **RIGHT** | 0 | min, msec | `btn_l` → LEFT |

---

#### `tick_gen_100hz`
시스템 클럭(100MHz) 분주 → **10ms(100Hz) tick** 생성.  
Stopwatch는 `run_stop_sw` 신호로 제어, Watch는 항상 `1'b1` 고정.

---

#### `watch_tick_counter` (parameterized)

입력 tick × `TIMES` 카운트 → 원하는 주기 tick 생성.

| 인스턴스 | 입력 tick | TIMES | 출력 tick |
|---------|:--------:|:-----:|:--------:|
| msec_counter | 10ms | 100 | 1sec |
| sec_counter | 1sec | 60 | 1min |
| min_counter | 1min | 60 | 1hour |
| hour_counter | 1hour | 24 | (wrap) |

`i_sel_modify` (LEFT=1/RIGHT=0) × `sw_hm_sm` 조합으로 수정 대상 특정:

| | msec | sec | min | hour |
|--|:----:|:---:|:---:|:----:|
| `i_sel_modify` | 0 | 1 | 0 | 1 |
| `sw_hm_sm` | 0 | 0 | 1 | 1 |

---

#### `stopwatch_datapath` / `watch_datapath`
Control Unit 상태에 따라 FND 표시값 (hour / min / sec / msec) 계산 출력.

---

#### `mux_2x1_w_sw_sel`
`sw[1]`에 따라 Stopwatch 또는 Watch 데이터 선택 → `U_FND_CNTL`로 전달.

---

#### `fnd_controller`
24bit 시간 데이터를 FND 표시 가능한 형태로 변환.

- `digit_splitter`: 1의 자리 / 10의 자리 분리
- `dot_onoff`: 100의 자리 dot 0.5초 주기 점멸
- `mux_8X1`: sec.msec / hour.min 선택
- `mux_2x1`: `sw[2]`로 최종 출력 선택

---

## 📊 시뮬레이션

| 시나리오 | 확인 내용 |
|---------|---------|
| ASCII Decoder | `rx_done` 다음 clk 상승엣지에서 해당 tick 발생 확인 |
| Watch Mode (UART) | `'u'` 입력 → `o_u` → hour 12→13 증가 확인 |
| Stopwatch Mode (UART) | `'r'` 입력 → Run/Stop 전환 확인 |
| Button Debounce | 800kHz 지점에서 신호 1번만 발생 확인 |
| Watch tick chain | msec 100번 → sec 증가 정상 동작 확인 |
| Stopwatch Clear | Stop 상태에서만 Clear 동작, Run 중 비활성 확인 |

---

## 🐛 Trouble Shooting

### ASCII Decoder tick 생성 안됨
- **원인 1**: Instance 포트 연결 오류 — RX 8bit 출력이 아닌 1bit 입력을 받아옴
- **원인 2**: 잘못된 tick 생성 로직 — 해당 ASCII 값 입력 구간 전체에서 매 클럭 up/down 반복
- **해결**: `rx_done` (STOP→IDLE 전환 시점 1clk 펄스) 활용해 tick 생성 → 정확한 1clk 출력

---

## 🧪 검증 (UVM-style Testbench)

> 팀 프로젝트 (신성민, 송주연) | 2026.03.03

### UART FIFO 검증

**검증 시나리오**
- UART RX Frame 생성 후 RX핀 전달 → FIFO에 정상 저장 여부 확인
- S/W Queue와 FIFO Pop 데이터 비교
- 입력 데이터 수 vs Pop 횟수로 Empty 여부 판단
- Byte 단위 특정 값이 UART TX Frame으로 올바르게 변환되는지 확인
- 개별 / 동시 발생 케이스 모두 검증

**구조**

```
Generator (trans_genBroadcast)
    │ rx_valid / rx_transfer_data
    │ rxfifo_get / rxfifo_get_times
    │ tx_valid / tx_input_data
    ▼
Driver ──────────────────────────────────► DUT (uart_sys)
    create_rx_frame_stream()                   │
    create_rxfifo_instruction()                │
    create_tx_instruction()               Monitor
                                    receiver_rxfifo_data()
                                    receiver_tx_frame_stream()
                                               │
                                          Scoreboard
                                    (Queue 비교 / TX Frame 검증)
```

**Driving / Sampling Timing**

| 대상 | Driving | Sampling |
|------|---------|---------|
| FIFO / TX | `posedge clk + 1ns` | `negedge clk` |
| UART RX | Baud rate 기준 시간 딜레이 | — |
| UART TX | — | Baud rate 기준 비트 단위 수신 |

**Trouble Shooting**
- Monitor에서 한 번의 샘플링이 아닌 여러 번의 샘플링이 필요한 상황 발견 (FIFO 다중 Pop, UART TX 비트 분할 전송)
- 해결: `rxfifo_data[]` 배열화로 Pop 횟수만큼 저장, TX는 비트 단위 누적 샘플링 후 Scoreboard 전달

---

### Stopwatch 검증

**검증 시나리오**
- `mode`, `clear`, `run_stop` 랜덤 생성
- Testbench 내부 자체 Stopwatch와 DUT 출력값 비교

**Scoreboard 내부 자체 Stopwatch 동작**
```
posedge마다 100hz tick count
100 tick → msec++  (0~99)
msec=99  → sec++   (0~59)
sec=59   → min++   (0~59)
min=59   → hour++  (0~23)
mode / clear / run_stop 입력에 따라 DUT와 동일하게 동작
```

**Driving / Sampling Timing**
- 신호 유지: 30msec (msec 변화 관찰 목적)
- Driving: `posedge clk + 1ns`
- Sampling: `negedge clk`

**Trouble Shooting**

| # | 문제 | 원인 | 해결 |
|---|------|------|------|
| 1 | clear 시 100hz tick count 초기화 안됨 | `tick_gen_100hz`에 clear input 없음 | DUT `tick_gen_100hz`에 `clear` 입력 추가, reset과 동일 동작 |
| 2 | 신호 입력 타이밍과 Stopwatch 값 변경 타이밍 불일치 | Generator 지연 시간 설정 오류 (3ms - 1clk) | Generator 지연 시간 수정 |

---

### Watch 검증

**검증 시나리오**
- `left`, `right`, `up`, `down`, `sw_2` 랜덤 생성
- Watch 시간 수정 동작 확인

| 입력 | 동작 |
|------|------|
| `left` / `right` | FND 왼쪽(hour/sec) / 오른쪽(min/msec) 선택 |
| `up` / `down` | 선택 자리 값 증가 / 감소 |
| `sw_2=0` | sec/msec 수정 |
| `sw_2=1` | hour/min 수정 |

**Driving / Sampling Timing**
- Driving: `negedge clk` (left/right/up/down 1clk만 유지 — 중복 동작 방지)
- Sampling: `posedge clk` (negedge에서 시간 데이터 변경 후 안정성 고려)

**Trouble Shooting**

| # | 문제 | 원인 | 해결 |
|---|------|------|------|
| 1 | DUT와 Testbench Timing 불일치 | Driving/Sampling Timing 다수 조합 시도 | Timing 수정으로 해결 |
| 2 | hour 증가해야 하는데 sec 증가 | Monitor에서 `sw_2` 누락 | Monitor interface에 `sw_2` 추가 → All Pass |

---

## 💡 고찰 및 개선할 점

- 코딩 전 개념을 정확히 이해하고 ASM / FSM을 먼저 작성하기
- 설계 오류 발생 시 오류 화면·코드 등 Trouble Shooting 과정을 기록으로 남기기
- 체계적인 검증 시나리오를 사전에 설계하고 시뮬레이션 진행하기
- 시연 영상에 자막을 추가해 동작 상황 이해를 돕기
