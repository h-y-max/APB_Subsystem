# APB_UART

  带完整 APB 从机接口的 UART 外设（8N1，LSB first，全双工），含寄存器组、可屏蔽中断与 TX 反压。为便于板级调试与仿真验证，片内内置一个"用户接口 → APB 主机"的状态机，形成自包含的 APB 系统：用户侧只需给出地址/数据/读写使能，主机状态机自动完成 APB setup/access 时序。
  
  语言：Verilog-2001，全部模块参数化

## 特性

- 标准 APB 协议：PSEL / PENABLE 两阶段（setup / access），支持 PREADY 等待状态，CTRL 寄存器写入带 PSTRB 字节选通
- UART 8N1（1 起始位 + 8 数据位 + 1 停止位），波特率参数化，默认波特率:9600  时钟频率:50 MHz
- 寄存器接口：TX / RX / 状态 / 控制，偏移 0x00 / 0x04 / 0x08 / 0x0C
- 中断：TX/RX 完成可屏蔽中断，flag 由硬件置位、软件清除（写 CTRL[31] 清 TX flag，读 RX 清 RX flag）
- TX 忙时写入由 PREADY 挂起（反压），不会丢数据
- 接收路径：双触发器同步 + 下降沿起始位检测 + 中点采样 + 伪起始位剔除
- CLOCK 参数化：testbench 以 1 MHz 时钟仿真，将 9600 波特的位时间压缩到 104 拍，大幅缩短仿真时间

## 参数

- CLOCK：系统时钟频率，默认 50_000_000；仿真时改小可加速（本仓库 testbench 用 1_000_000）
- BAUD：波特率，uart_tx / uart_rx 内参数，默认 9600

## 顶层接口

- CLK / reset_n：时钟、异步复位（低有效）
- user_en：发起一次传输（打一拍）
- user_write：1 写 / 0 读
- user_addr / user_wdata：地址 / 写数据
- user_tran_done：传输完成脉冲
- user_rdata：读回数据（tran_done 时有效）
- IRQ：中断输出
- uart_tx / uart_rx：串口收发引脚

用户侧协议：驱动 user_en 一拍并给出 addr/write/wdata → 等待 user_tran_done → 读操作取 user_rdata。

## 寄存器映射

- 0x00 TX（写）：低 8 位写入待发送数据，写入即启动发送；TX 忙时由 PREADY 挂起
- 0x04 RX（读）：低 8 位为最新接收到的字节；读后自动清除 RX 中断 flag
- 0x08 STA（读）：bit0 Rx_done，bit1 Tx_done，bit2 rx_irq_flag，bit3 tx_irq_flag，bit4 rx_irq_en，bit5 tx_irq_en，bit6 tx_busy
- 0x0C CTRL（写，PSTRB[0] 有效）：bit0 → tx_irq_en，bit1 → rx_irq_en；写 bit31 = 1 清除 TX 中断 flag；读回低两位为 {rx_irq_en, tx_irq_en}

## 设计说明

### 1. 系统结构

APB_uart_top 内含 APB_uart_Master 与 APB_uart_Slave。Master 将用户侧简单握手翻译成标准 APB 时序；Slave 是 UART 外设本体（寄存器组 + uart_tx + uart_rx）。真实 SoC 中 APB 主机通常由 CPU 或总线互联担任，本设计的 Master 是自包含验证的简化模型。

### 2. APB Master 状态机

三段式六状态：IDLE → WR / RD → ENABLE → DONE → WAIT → IDLE，状态编码采用 6 bit 单热式。WR / RD 状态拉 PSEL（PENABLE = 0）完成 setup；ENABLE 状态拉 PENABLE 进入 access 并等待 PREADY，从机反压时原地等待；DONE 撤 PSEL/PENABLE；WAIT 打一拍 user_tran_done 并采样 PRDATA。

### 3. APB Slave 寄存器组与反压

寄存器译码用低 8 位地址偏移。PREADY 为组合逻辑：TX 忙时写 TX 寄存器拉低 PREADY 插入等待，其余时刻恒 1。中断采用「使能位 + flag 位」结构：硬件事件置 flag，IRQ 为两 flag 相或；软件通过写 CTRL[31] / 读 RX 清除对应 flag。

### 4. UART 发送

发送数据在 send_go 上升沿锁存，send_go 经两级触发器同步防亚稳态。波特率计数器驱动 10 位状态机（起始位 → 8 数据位 LSB first → 停止位），帧结束打一拍 Tx_done，Slave 据此清 busy 并置中断 flag。

### 5. UART 接收

uart_rx 经两级同步后做下降沿检测启动接收。位计数器在半波特率处跳变，对每一位做中点采样；起始位中点若线已回高，判定为伪起始位并中止接收（毛刺剔除）。8 位数据采入移位寄存器，停止位中点处更新 RX 寄存器并打一拍 Rx_done。

## 验证

Testbench 为自校验结构，不依赖 DUT 内部信号：

- 邮箱机制：发送数据写入 tx_model_mem，TB 在 uart_rx 上发出的帧记入 rx_model_mem
- scoreboard：独立解析 uart_tx 线协议（起始位校验 → 逐位采样 → 停止位校验），逐帧与邮箱比对，任何不符立即 FAIL
- 任务化激励：apb_user_write / apb_user_read / apb_write_tx / rx_send_byte
- 看门狗 1 ms 防挂死

测试点：

- TP1a：复位后空闲信号 —— uart_tx = 1，IRQ = 0
- TP1b：复位后 STA 寄存器读出全 0
- TP2：TX 单字节（0xA5）线级比对
- TP3：TX 背靠背 3 字节（0x11/0x22/0x33）逐帧比对
- TP4：RX 单字节，APB 读 RX 寄存器与模型比对
- TP5：RX 连续 3 字节，逐字节读回比对

仿真波形：

![APB_uart 仿真波形](APB_UART.png)

## 可改进点

- 接收路径无帧错误检测（未校验停止位）、无溢出标志，新帧会覆盖 RX 寄存器，依赖软件及时读走
- uart_tx / uart_rx 的输入同步链进程无复位，上电初态依赖管脚默认电平
- STA 与 CTRL 回读中 irq_en 的 bit 位置不一致（STA bit4/5，CTRL bit0/1），软件编程易误用
- testbench 未覆盖：中断使能→触发→清除全路径、TX 忙时写挂起场景、PSTRB 部分选通；scoreboard 未对 IRQ 时序做检查
