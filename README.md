## ⏱️ UART · FIFO · Stopwatch · Watch · Sensor 통합 설계 및 검증
온디바이스AI 시스템 반도체 설계 1기 | 송주연 | 대한상공회의소 서울기술교육센터 | 2026.03.03

--------------------------------------------------------------------------------

### 프로젝트 개요
- PC와 FPGA 간의 **UART 양방향 통신 프로토콜** 설계
- **FIFO 구조의 데이터 버퍼**를 통해 안정적인 데이터 송수신 환경을 구축
- Basys3 보드의 버튼·스위치 및 PC 키 입력을 통해 동작하는 **디지털 스톱워치와 시계** 구현
- **초음파 센서 및 온습도 센서** 데이터를 실시간으로 처리하여 FND에 출력하는 통합 시스템을 설계
- System Verilog를 이용한 **UVM-style 검증**

--------------------------------------------------------------------------------

### 기술 스택 및 사양
| 항목 | 내용 |
| ------ | ------ |
| **언어** | Verilog HDL |
| **보드** | Digilent Basys3 (Artix-7 xc7a35t) |
| **개발 툴** | Vivado 2023.1 |
| **통신 프로토콜** | UART Full Duplex (Baud rate: 9600bps, x16 Over Sampling) |
| **데이터 버퍼** | FIFO (RX / TX 각각 구현) |
| **외부 센서** | HC-SR04 (초음파 거리), DHT11 (온습도) |

--------------------------------------------------------------------------------

### 입출력 소자 및 인터페이스
<img width="622" height="375" alt="Image" src="https://github.com/user-attachments/assets/25e76c03-2bd7-4d64-a605-6af052fe7893" />

### Switches & Buttons
| 소자 | 역할 | 상세 동작 |
| ------ | ------ | ------ |
| **sw[0]** | 시계 카운트 방향 | 0: Up count / 1: Down count |
| **sw[1]** | 시계/센서 종류 선택 | 0: Watch-SR04 / 1: Stopwatch-DHT11 |
| **sw[2]** | 시계/센서 모드 선택 | 0: 시계(sw/w) / 1: 센서(SR04/DHT11) |
| **sw[3]** | 표시할 데이터 선택 | 0: sec.msec-습도 / 1: hour.min-온도 |
| **btn_l / btn_r** | 기능 제어 | 스톱워치 Clear/Run-Stop, 시계 수정 자리 선택 |
| **btn_u / btn_d** | 값 수정 | 시계 설정 모드에서 시간 값 증가/감소 |

### UART Key Input (PC -> FPGA)
*   **'u' / 'd'**: 시계 값 증가 / 감소
*   **'l' / 'r'**: 시계 값 수정 자리 선택 또는 스톱워치 제어 (Clear/Run-Stop)
*   **'s'**: 현재 FND 출력값(시간 또는 센서 데이터)을 PC 터미널로 전송

--------------------------------------------------------------------------------

### 전체 Block Diagram

<img width="12006" height="5610" alt="image" src="https://github.com/user-attachments/assets/7cfc5730-eb53-4d99-beea-c8d390fb81b3" />


### 모듈 상세 설명

### 1. UART & FIFO
   <img width="1900" height="1223" alt="Image" src="https://github.com/user-attachments/assets/87c92ea5-4d29-45c3-b80e-4579c5abd08d" />

*   **UART RX/TX**: 비동기 통신을 수행하며, 1비트의 보드 레이트 오차로 인한 데이터 손실을 줄이기 위해 **x16 오버샘플링** 기법을 적용했습니다.
*   **FIFO Buffer**: UART 수신/송신 시 데이터 유실을 방지하고 흐름을 제어하기 위해 RX와 TX 단에 각각 버퍼를 설계했습니다.
*   **ASCII Decoder/Sender**: UART로 입력된 문자를 시스템 제어용 **Tick 신호**로 변환하거나 내부 데이터를 ASCII 포맷으로 변환하여 송신합니다.

### 2. Stopwatch & Watch (Module Structure)
*   **Stopwatch**:
    *   **Control Unit (FSM)**: `STOP`, `RUN`, `CLEAR` 상태를 관리하며, `RUN` 상태에서는 `CLEAR`가 동작하지 않도록 설계되었습니다.
    *   **Datapath**: 100Hz tick을 기준으로 밀리초부터 시간까지 카운트하며, `mode` 신호에 따라 정방향/역방향 카운트를 수행합니다.
*   **Watch**: 
    *   **Control Unit**: 일반 동작 모드와 시간 수정(UP/DOWN) 모드를 관리합니다.
    *   **Modify Selector**: 버튼 입력을 받아 시/분/초/밀리초 중 수정할 위치(`LEFT`/`RIGHT`)를 결정합니다.
    *   **Datapath**: 현재 시간을 유지하며, 수정 신호 발생 시 해당 자리의 값을 가감합니다.

### 3. Sensors
| SR04 | DHT11 |
| ------ | ------ |
|<img width="335" height="215" alt="image" src="https://github.com/user-attachments/assets/f9622543-7b74-4d92-9d1c-4604d23bc843" /> | <img width="400" height="250" alt="image" src="https://github.com/user-attachments/assets/233c00fe-a0f7-4697-8852-764639f22188" /> |

*   **SR04 (초음파 거리 센서)**: 40kHz 펄스를 발생시킨 후 Echo 신호의 High 유지 시간을 측정하여 거리(cm)로 환산합니다.
*   **DHT11 (온습도 센서)**: 단일 와이어 **Half Duplex** 통신을 통해 40비트 데이터를 수신하며, 체크섬을 통해 유효성을 검증합니다.
  
| DHT11 FSM | DHT11 ASM |
| ------ | ------ |
| <img width="933" height="417" alt="image" src="https://github.com/user-attachments/assets/1790560a-3443-417f-9359-451897545356" /> | <img width="1400" height="1000" alt="image" src="https://github.com/user-attachments/assets/b1965f36-df6a-441a-9998-c733bd910382" />




--------------------------------------------------------------------------------

### 시뮬레이션 및 동작 확인
*   **전체 검증**: 버튼, 스위치, UART 명령 입력을 통해 스톱워치와 시계의 모든 기능이 정상 구동되는지 Top Module 레벨에서 확인했습니다.
*   **Waveform 분석**
  <img width="500" height="370" alt="image" src="https://github.com/user-attachments/assets/d4205cc8-6432-4b93-b3fa-b7e7a9f9f45d" />
  
 *   **Stopwatch**: `r` 키 입력 시 `Run/Stop` 전환 및 `Clear` 동작의 타이밍을 검증했습니다.
 *   **Watch**: 시간 수정 모드에서 각 단위별(msec, hour 등) 값 증감이 정상적으로 FND에 반영됨을 확인했습니다.
 *   **Sensors**: 초음파 거리 데이터 및 온습도 40비트 데이터 수신 과정을 분석했습니다.
      
 *   **ComPort Master**로 ASCII 문자 송신 및 FPGA 반환 데이터 수신하여 UART 통신 동작 검증
   <img width="500" height="382" alt="image" src="https://github.com/user-attachments/assets/f7b2f3a9-dd29-4fca-a546-4707be81e74b" />

--------------------------------------------------------------------------------

### UVM-style 검증 (Stopwatch / Watch)
시스템의 신뢰성을 위해 Testbench 내부의 Golden Model과 DUT 출력을 비교하는 검증을 수행했습니다.,

### 1. Stopwatch 검증
*   **UVM 구조**
<img width="1045" height="627" alt="image" src="https://github.com/user-attachments/assets/dddfb0bf-02ae-43d4-bfe6-ea019911cfc4" />

*   **시나리오**: `mode`, `clear`, `run_stop` 신호를 랜덤 생성하여 DUT와 Scoreboard 내 자체 카운터 값을 비교했습니다.
*   **Timing**: Driving(posedge + 1ns), Sampling(negedge)을 통해 데이터 안정성을 확보했습니다.
*   **결과**: 총 3001회 검증 시도, **All Pass**

### 2. Watch 검증
*   **UVM 구조**
<img width="1474" height="857" alt="image" src="https://github.com/user-attachments/assets/440bc80e-5314-484f-96d0-afd108f5a4fb" />

*   **시나리오**: `left`, `right`, `up`, `down`, `sw_2` 신호를 랜덤 생성하여 시간 수정 동작을 검증했습니다.
*   **Timing**: 중복 동작 방지를 위해 입력 신호를 1클럭만 유지하고, negedge에서 값을 변경한 후 posedge에서 샘플링했습니다.
*   **결과**: 총 202회 검증 시도, **All Pass**

| Stopwatch 검증 결과 | Watch 검증 결과 |
| ------ | ------ |
| <img width="390" height="254" alt="image" src="https://github.com/user-attachments/assets/c3c91034-7b09-484f-8994-000b02bbf3ad" /> | <img width="433" height="290" alt="image" src="https://github.com/user-attachments/assets/bef3992a-2516-4389-a713-f0c693064aea" /> |


--------------------------------------------------------------------------------

### 🐛 Trouble Shooting
*  **Stopwatch DUT 설계 오류**
  - **문제**: UVM-style 검증 중 Log를 확인해보니 시계의 실제 동작이 예상값과 다른 경우가 있었음
  - **원인**: 기존 DUT 설계에서 100Hz tick count가 reset 시에만 초기화되고 clear 입력 시에는 초기화되지 않고 계속 증가함
  - **해결-1**: DUT 설계에 맞춰 UVM-style의 Testbench의 시계 reference model에서도 100Hz tick count가 reset 시에만 초기화되도록 설계를 변경하니 DUT와 Testbench 동작이 정확히 일치함
    - 이 해결의 잘못된 점: 설계 의도 상 clear는 reset과 같은 동작을 해야 하므로 기존 Testbench 설계가 맞는데 Simulation을 통과하기 위해 Testbench를 변경한 셈이 됨
 - **해결-2**: 설계 의도에 맞게 DUT의 reset과 clear가 완전히 같은 동작을 하도록 설계를 변경함


### 고찰
- 검증의 목적이 Simulation All Pass가 아닌 DUT가 의도한 대로 동작하는지 혹은 오류는 없는지 찾아내는 과정이라는 것을 다시 한번 깊이 인지하게 되었다.

