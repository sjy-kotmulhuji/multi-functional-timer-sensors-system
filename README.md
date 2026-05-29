# FPGA 설계 프로젝트: Stopwatch & Watch + UART Communication

> Verilog / Vivado | Basys3 (xc7a35t) | 온디바이스AI 시스템 반도체 설계 1기 — 송주연

---

## 📁 Repository Structure

```
├── stopwatch_watch/       # Project 1: Stopwatch & Watch (Verilog)
│   ├── src/
│   └── sim/
├── uart/                  # Project 2: UART with FIFO & ASCII Codec (Verilog)
│   ├── src/
│   └── sim/
└── README.md
```

---

## 📌 Project 1: Stopwatch & Watch

### 개요
Verilog를 이용해 FPGA 보드(Basys3)에 **Stopwatch**와 **Watch** 기능을 구현한 프로젝트.

| 항목 | 내용 |
|------|------|
| 언어 | Verilog |
| 보드 | Basys3 (xc7a35t) |
| 입력 | System Clock, Reset, 스위치 3개, 버튼 4개 |
| 출력 | FND Display (fnd_digit[3:0], fnd_data[7:0]) |

### 기능

**Stopwatch**
- Run / Stop
- Up Count / Down Count
- Hour&Minute / Sec&msec 표시 모드 선택
- Clear (Stop 상태에서만 동작)
- Reset

**Watch**
- Hour&Minute / Sec&msec 표시 모드 선택
- 시간 수정 (시/분/초 개별 증가·감소)
- Reset 직후 별도 Start 없이 즉시 실행

### 입출력 소자 배치

| 신호 | 소자 | 기능 |
|------|------|------|
| sw[0] | Switch | 0: Up count / 1: Down count |
| sw[1] | Switch | 0: Watch / 1: Stopwatch |
| sw[2] | Switch | 0: sec.msec 표시 / 1: hour.min 표시 |
| btn_l | Button | Stopwatch: Clear / Watch: 왼쪽 두 자리 선택 |
| btn_r | Button | Stopwatch: Run/Stop / Watch: 오른쪽 두 자리 선택 |
| btn_u | Button | Watch: 선택한 자리 값 증가 |
| btn_d | Button | Watch: 선택한 자리 값 감소 |
| reset | Button | 전체 Reset |

### Block Diagram

```
[btn_l] → U_BD_CLEAR   ─┐
[btn_r] → U_BD_RUNSTOP ─┤→ U_SW_CONTROL_UNIT → U_STOPWATCH_PATH ─┐
[btn_u] → U_BD_UP      ─┤                                          │
[btn_d] → U_BD_DOWN    ─┘→ U_W_CONTROL_UNIT  → U_WATCH_PATH    ──┤
                                                                    ↓
                                                         U_Mux_W_SW_SEL (sw[1])
                                                                    ↓
                                                            U_FND_CNTL
                                                                    ↓
                                                     fnd_digit[3:0] / fnd_data[7:0]
```

### 모듈 설명

#### `btn_debounce`
버튼 입력 시 발생하는 채터링을 제거하고, 입력 신호를 **1 clock 펄스**로 변환해 출력.
- 100kHz tick을 생성해 8-tap Shift Register로 필터링
- 입력이 최소 80us 이상 유지되어야 `debounce = 1`
- `debounce & (~edge_reg)`로 rising edge 1clk만 출력

#### `stopwatch_control_unit`
버튼 신호를 입력받아 Stopwatch의 상태를 결정하는 **FSM (Moore Machine)**.

| State | o_run_stop | o_clear | 전이 조건 |
|-------|-----------|---------|----------|
| STOP  | 0 | 0 | `i_run_stop=1` → RUN, `i_clear=1` → CLEAR |
| RUN   | 1 | 0 | `i_run_stop=1` → STOP (CLEAR 비활성) |
| CLEAR | 0 | 1 | `i_run_stop=1` → RUN |

#### `watch_control_unit`
버튼 신호를 입력받아 Watch 시간 수정 방향을 결정하는 **FSM (Moore Machine)**.

| State  | o_up | o_down |
|--------|------|--------|
| NORMAL | 0 | 0 |
| UP     | 1 | 0 |
| DOWN   | 0 | 1 |

버튼을 누르면 1clk 동안 UP/DOWN 상태로 전이 후 NORMAL로 복귀.

#### `watch_modify_sel`
Watch 시간 수정 자리(LEFT/RIGHT)를 결정하는 **FSM (Moore Machine)**.
- `LEFT (1)`: hour, sec 수정
- `RIGHT (0)`: min, msec 수정
- `btn_l` 입력 시 LEFT 유지 또는 복귀 / `btn_r` 입력 시 RIGHT로 전이

#### `tick_gen_100hz`
시스템 클럭(100MHz)을 분주해 **10ms(100Hz) tick** 발생.
- `run_stop_sw = 1`일 때만 tick 발생 (Stopwatch에 사용)
- Watch는 항상 `run_stop_sw = 1'b1` 고정으로 연결

#### `watch_tick_counter` (parameterized)
입력 tick과 파라미터 `TIMES`를 이용해 원하는 주기의 tick 생성. Watch 실시간 동작에 사용.

| 인스턴스 | 입력 tick | TIMES | 출력 tick |
|---------|----------|-------|----------|
| msec_counter | 10ms | 100 | 1sec |
| sec_counter  | 1sec | 60  | 1min |
| min_counter  | 1min | 60  | 1hour |
| hour_counter | 1hour | 24 | (wrap) |

`i_sel_modify`와 `sw_hm_sm`의 조합으로 현재 수정 대상을 특정해 up/down 적용.

#### `stopwatch_datapath` / `watch_datapath`
Control Unit에서 받은 상태(run_stop, clear, mode / left, right, up, down)에 따라 FND에 표시될 hour, min, sec, msec 값을 계산해 출력.

#### `mux_2x1_w_sw_sel`
sw[1] 값에 따라 Stopwatch 또는 Watch 데이터 중 FND에 표시할 값을 선택해 출력.

#### `fnd_controller`
입력된 24bit 시간 데이터를 FND 표시 가능한 형태로 변환.
- `digit_splitter`: 각 시간 값의 1의 자리 / 10의 자리 분리
- `dot_onoff`: 100의 자리 dot을 0.5초마다 점멸
- `mux_8X1`: sec.msec 표시 / hour.min 표시 선택
- `mux_2x1`: sw[2]로 최종 출력 선택

---

## 📌 Project 2: UART Communication with FIFO & ASCII Codec

### 개요
UART 송수신에 FIFO 버퍼를 결합하고, ASCII 인코딩/디코딩 로직을 추가한 통신 시스템.  
PC에서 문자를 전송하면 FPGA가 수신·디코딩하여 처리 결과를 다시 PC로 송신.

| 항목 | 내용 |
|------|------|
| 언어 | Verilog |
| 보드 | Basys3 (xc7a35t) |
| 통신 방식 | UART (Full Duplex) |
| 버퍼 | FIFO (RX / TX 각각) |

### 시스템 구성

```
[PC]
 │  uart_rx
 ▼
UART RX ──rx_data(8bit)──→ FIFO RX ──pop_data(8bit)──→ ASCii DECODER
           rx_done──push↗            empty(NOT)──pop↗       │o_r / o_l / o_u / o_d
                                                             │uart_tx
                                                             ▼
UART TX ←──tx_data(8bit)── FIFO TX ←─push_data(8bit)── ASCii SENDER
  uart_tx↓    tx_start↗    empty──pop→                   i_send / i_sw(2bit)
 [PC]          tx_busy↗
```

### FIFO를 함께 사용하는 이유
UART RX는 데이터 수신 즉시 처리하지 않으면 다음 바이트에 덮어씌워져 데이터가 소실됨.  
FIFO가 생산자(UART RX / ASCii Sender)와 소비자(ASCii Decoder / UART TX)의 **속도·타이밍 차이를 완충**하여 양쪽이 서로 독립적으로 동작 가능.

| 신호 | 역할 |
|------|------|
| `push` | 새 데이터 FIFO에 저장 |
| `pop`  | FIFO에서 데이터 꺼냄 |
| `empty`| 비어있으면 pop 차단 |
| `full` | 가득 차면 push 차단 |

### 모듈 설명

#### `uart_rx`
- 비동기 직렬 데이터를 수신해 8bit 병렬 데이터(`rx_data`)로 변환
- 수신 완료 시 `rx_done` 1clk 펄스 출력 → FIFO RX push 트리거

#### `fifo_rx` / `fifo_tx`
- 수신/송신 데이터를 임시 저장하는 FIFO 버퍼
- `empty` / `full` 신호로 흐름 제어

#### `ascii_decoder`
- FIFO RX에서 꺼낸 ASCII 코드를 해석해 방향 신호(`o_r`, `o_l`, `o_u`, `o_d`) 출력
- `rx_done`(NOT empty) 신호로 pop 트리거
- 디코딩 결과에 따라 ASCii Sender에 전송 요청(`uart_tx`)

#### `ascii_sender`
- `i_send` 신호를 받으면 해당 ASCII 데이터를 FIFO TX에 push
- `i_sw[1:0]`로 전송할 데이터 선택
- `tx_fifo_full` 체크로 FIFO 포화 방지

#### `uart_tx`
- FIFO TX에서 데이터를 꺼내 직렬로 송신
- `tx_busy` 신호로 전송 중 상태 표시, 완료 시 `tx_done` 출력

---

## 🔧 개발 환경

| 항목 | 내용 |
|------|------|
| Tool | Vivado 2023.1 |
| Board | Digilent Basys3 (xc7a35t) |
| Language | Verilog |
| Simulation | Vivado Simulator (xsim) |

---

## 💡 고찰 및 개선할 점

- 설계 중 오류 발생 시 Trouble Shooting 과정(오류 화면, 코드 등)을 기록으로 남기기
- 체계적인 검증 시나리오를 사전에 설계하고 시뮬레이션하기
- 시연 영상에 자막을 추가해 동작 상황 이해를 돕기
