`timescale 1ns / 1ps

interface watch_interface (
    input logic clk
);
    logic       reset;
    logic       left;
    logic       right;
    logic       up;
    logic       down;
    logic       sw_2;
    logic [6:0] msec;
    logic [5:0] sec;
    logic [5:0] min;
    logic [4:0] hour;

    property p_reset_check;
        @(posedge clk) reset |=> (msec == 0 && sec == 0 && min == 0 && hour == 12);
    endproperty

    property p_msec_max_check;
        @(posedge clk) msec <= 99;
    endproperty

    property p_sec_max_check;
        @(posedge clk) sec <= 59;
    endproperty

    property p_min_max_check;
        @(posedge clk) min <= 59;
    endproperty

    property p_hour_max_check;
        @(posedge clk) hour <= 23;
    endproperty

    reset_check :
    assert property (p_reset_check)
    else $display("%t : Reset Check Fail", $time);
    msec_max_check :
    assert property (p_msec_max_check)
    else $display("%t : Msec Max Check Fail. msec = %d", $time, msec);
    sec_max_check :
    assert property (p_sec_max_check)
    else $display("%t : Sec Max Check Fail. sec = %d", $time, sec);
    min_max_check :
    assert property (p_min_max_check)
    else $display("%t : Min Max Check Fail. min = %d", $time, min);
    hour_max_check :
    assert property (p_hour_max_check)
    else $display("%t : Hour Max Check Fail. hour = %d", $time, hour);
endinterface

class transaction;
    logic          reset;
    rand bit       left;
    rand bit       right;
    rand bit       up;
    rand bit       down;
    rand bit       sw_2;
    logic    [6:0] msec;
    logic    [5:0] sec;
    logic    [5:0] min;
    logic    [4:0] hour;

    constraint no_duplicate {left + right + up + down <= 1;}

    function void display(string name);
        $display(
            "%t : [%s] left = %b, right = %b, up = %b, down = %b, sw_2 = %b, msec = %d, sec = %d, min = %d, hour = %d",
            $time, name, left, right, up, down, sw_2, msec, sec, min, hour);
    endfunction  //display()
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual watch_interface watch_if;
    //event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual watch_interface watch_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.watch_if = watch_if;
        // this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            repeat (5) begin
                @(posedge (watch_if.clk));  //6500
            end
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual watch_interface watch_if;
    // event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual watch_interface watch_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.watch_if = watch_if;
    endfunction

    task preset();
        #1;
        watch_if.reset = 1;
        @(posedge (watch_if.clk));
        @(negedge (watch_if.clk));
        watch_if.reset = 0;
        @(negedge (watch_if.clk));
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(negedge (watch_if.clk));  //7000
            
            watch_if.left  = tr.left;
            watch_if.right = tr.right;
            watch_if.up    = tr.up;
            watch_if.down  = tr.down;
            watch_if.sw_2  = tr.sw_2;
            tr.display("drv");
            @(negedge (watch_if.clk));  //8000
            watch_if.left  = 0;
            watch_if.right = 0;
            watch_if.up    = 0;
            watch_if.down  = 0;
            #1;
            tr.display("drv");  //1clk 후 반영됨
            //-> gen_next_ev;
        end
    endtask
endclass

class monitor;
    transaction tr;
    virtual watch_interface watch_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual watch_interface watch_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.watch_if = watch_if;
    endfunction

    task run();
        forever begin
            tr = new();
            @(posedge (watch_if.clk));
            #1;  //7600
            tr.reset = watch_if.reset;
            tr.left  = watch_if.left;
            tr.right = watch_if.right;
            tr.up    = watch_if.up;
            tr.down  = watch_if.down;
            tr.sw_2  = watch_if.sw_2;
            tr.msec  = watch_if.msec;
            tr.sec   = watch_if.sec;
            tr.min   = watch_if.min;
            tr.hour  = watch_if.hour;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    // event gen_next_ev;
    int scb_msec = 0, scb_sec = 0, scb_min = 0, scb_hour = 12;
    bit scb_mod_sel = 1;  //0: right, 1: left
    int try_cnt, pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
        //this.gen_next_ev  = gen_next_ev;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);

            tr.display("scb");
            if (tr.reset) begin
                scb_msec = 0;
                scb_sec = 0;
                scb_min = 0;
                scb_hour = 12;
                scb_mod_sel = 1;  //default: left
                $display("Reset hour = %d", scb_hour);
            end else begin
                if (tr.left) scb_mod_sel = 1;
                if (tr.right) scb_mod_sel = 0;
                if (tr.up) begin  //Up
                    if (tr.sw_2) begin  //h.m
                    $display("%b", tr.sw_2);
                        if (scb_mod_sel)
                            scb_hour = (scb_hour == 23) ? 0 : scb_hour + 1;
                        else scb_min = (scb_min == 59) ? 0 : scb_min + 1;
                    end else begin  //s.ms
                        if (scb_mod_sel)
                            scb_sec = (scb_sec == 59) ? 0 : scb_sec + 1;
                        else scb_msec = (scb_msec == 99) ? 0 : scb_msec + 1;
                    end
                end
                if (tr.down) begin  //Down
                    if (tr.sw_2) begin  //h.m
                        if (scb_mod_sel)
                            scb_hour = (scb_hour == 0) ? 23 : scb_hour - 1;
                        else scb_min = (scb_min == 0) ? 59 : scb_min - 1;
                    end else begin  //s.ms
                        if (scb_mod_sel)
                            scb_sec = (scb_sec == 0) ? 59 : scb_sec - 1;
                        else scb_msec = (scb_msec == 0) ? 99 : scb_msec - 1;
                    end
                end

            end
            tr.display("scb");
            if (!tr.reset) begin
                try_cnt++;
                if (tr.msec !== scb_msec || tr.sec !== scb_sec || tr.min !== scb_min || tr.hour !== scb_hour) begin
                    $display(
                        "%t: [FAIL] Unmatched! Exp:%d:%d:%d:%d Real:%d:%d:%d:%d",
                        $time, scb_hour, scb_min, scb_sec, scb_msec, tr.hour,
                        tr.min, tr.sec, tr.msec);
                    fail_cnt++;
                end else begin
                    $display("%t: [PASS] Time = %d:%02d:%02d.%02d", $time,
                             tr.hour, tr.min, tr.sec, tr.msec);
                    pass_cnt++;
                end
            end
            //  ->gen_next_ev;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    // event gen_next_ev;

    virtual watch_interface watch_if;

    function new(virtual watch_interface watch_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, watch_if);
        drv = new(gen2drv_mbox, watch_if);
        mon = new(mon2scb_mbox, watch_if);
        scb = new(mon2scb_mbox);
    endfunction

    task run();
        drv.preset();
        fork
            gen.run(40);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #30;

        $display("____________________________");
        $display("**   Watch verify     **");
        $display("****************************");
        $display("** total try count = %3d **", scb.try_cnt);
        $display("** pass count = %3d      **", scb.pass_cnt);
        $display("** fail count = %3d      **", (scb.try_cnt - scb.pass_cnt));
        $display("****************************");
        $stop;
    endtask
endclass

module tb_watch_sv ();

    logic clk;
    watch_interface watch_if (clk);

    environment env;

    watch_datapath dut (
        .clk  (clk),
        .reset(watch_if.reset),
        .left (watch_if.left),
        .right(watch_if.right),
        .up   (watch_if.up),
        .down (watch_if.down),
        .sw_2 (watch_if.sw_2),
        .msec (watch_if.msec),
        .sec  (watch_if.sec),
        .min  (watch_if.min),
        .hour (watch_if.hour)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(watch_if);

        env.run();
    end
endmodule

/*
`timescale 1ns / 1ps

interface watch_interface (
    input logic clk
);
    logic reset;
    logic left, right, up, down, sw_2;
    logic [6:0] msec;
    logic [5:0] sec, min;
    logic [4:0] hour;

    // --- Assertions (SVA) ---
    property p_reset_check;
        @(posedge clk) reset |=> (msec == 0 && sec == 0 && min == 0 && hour == 12);
    endproperty
    assert property (p_reset_check)
    else $display("%t : [SVA FAIL] Reset Check", $time);

    property p_msec_max;
        @(posedge clk) msec <= 99;
    endproperty
    assert property (p_msec_max)
    else $display("%t : [SVA FAIL] Msec Max", $time);
endinterface

// --- Transaction ---
class transaction;
    logic          reset;
    rand bit       left,  right, up, down, sw_2;
    logic    [6:0] msec;
    logic    [5:0] sec,   min;
    logic    [4:0] hour;

    constraint no_duplicate {left + right + up + down <= 1;}

    function void display(string name);
        $display(
            "%t : [%s] L:%b R:%b U:%b D:%b SW2:%b | Time %d:%02d:%02d.%02d",
            $time, name, left, right, up, down, sw_2, hour, min, sec, msec);
    endfunction
endclass

// --- Generator ---
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            if (!tr.randomize()) $fatal("Randomization failed");
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);  // Scoreboard가 비교를 마칠 때까지 대기
        end
    endtask
endclass

// --- Driver ---
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual watch_interface watch_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual watch_interface watch_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.watch_if = watch_if;
    endfunction

    task preset();
        @(negedge watch_if.clk);
        watch_if.reset <= 1;
        repeat (2) @(negedge watch_if.clk);
        watch_if.reset <= 0;
        $display("%t : [DRV] Reset Done", $time);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            // negedge에 값을 넣어 DUT가 다음 posedge에 안전하게 읽게 함
            @(negedge watch_if.clk);
            watch_if.left  <= tr.left;
            watch_if.right <= tr.right;
            watch_if.up    <= tr.up;
            watch_if.down  <= tr.down;
            watch_if.sw_2  <= tr.sw_2;
            tr.display("drv");
            @(negedge watch_if.clk);  // 1클럭 유지
            watch_if.left  <= 0;
            watch_if.right <= 0;
            watch_if.up    <= 0;
            watch_if.down  <= 0;
        end
    endtask
endclass

// --- Monitor ---
class monitor;
    transaction tr;
    virtual watch_interface watch_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual watch_interface watch_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.watch_if = watch_if;
    endfunction

    task run();
        forever begin
            // posedge 직후의 안정된 상태를 샘플링
            @(posedge watch_if.clk);
            
            tr = new();
            tr.reset = watch_if.reset;
            tr.left  = watch_if.left;
            tr.right = watch_if.right;
            tr.up    = watch_if.up;
            tr.down  = watch_if.down;
            tr.sw_2  = watch_if.sw_2;
            @(negedge watch_if.clk);
            tr.msec  = watch_if.msec;
            tr.sec   = watch_if.sec;
            tr.min   = watch_if.min;
            tr.hour  = watch_if.hour;
            tr.display("mon");
            mon2scb_mbox.put(tr);
        end
    endtask
endclass

// --- Scoreboard ---
class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    // 기대값 저장을 위한 내부 변수
    int scb_msec = 0, scb_sec = 0, scb_min = 0, scb_hour = 12;
    bit scb_mod_sel = 1;  // 1: Left, 0: Right
    int try_cnt, pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);

            // [1] Check: 이전 입력으로 계산된 기대값과 현재 DUT 출력 비교
            if (!tr.reset) begin
                try_cnt++;
                if (tr.msec == scb_msec && tr.sec == scb_sec && 
                    tr.min == scb_min && tr.hour == scb_hour) begin
                    $display("%t: [PASS] DUT:%d:%02d:%02d.%02d", $time,
                             tr.hour, tr.min, tr.sec, tr.msec);
                    pass_cnt++;
                end else begin
                    $display(
                        "%t: [FAIL] Exp %d:%02d:%02d.%02d | Real %d:%02d:%02d.%02d",
                        $time, scb_hour, scb_min, scb_sec, scb_msec, tr.hour,
                        tr.min, tr.sec, tr.msec);
                    fail_cnt++;
                end
            end

            // [2] Update: 현재 입력을 보고 '다음' 클럭의 기대값을 미리 계산
            if (tr.reset) begin
                scb_msec = 0;
                scb_sec = 0;
                scb_min = 0;
                scb_hour = 12;
                scb_mod_sel = 1;
            end else begin
                if (tr.left) scb_mod_sel = 1;
                if (tr.right) scb_mod_sel = 0;

                if (tr.up) begin
                    if (tr.sw_2) begin
                        if (scb_mod_sel)
                            scb_hour = (scb_hour == 23) ? 0 : scb_hour + 1;
                        else scb_min = (scb_min == 59) ? 0 : scb_min + 1;
                    end else begin
                        if (scb_mod_sel)
                            scb_sec = (scb_sec == 59) ? 0 : scb_sec + 1;
                        else scb_msec = (scb_msec == 99) ? 0 : scb_msec + 1;
                    end
                end
                if (tr.down) begin
                    if (tr.sw_2) begin
                        if (scb_mod_sel)
                            scb_hour = (scb_hour == 0) ? 23 : scb_hour - 1;
                        else scb_min = (scb_min == 0) ? 59 : scb_min - 1;
                    end else begin
                        if (scb_mod_sel)
                            scb_sec = (scb_sec == 0) ? 59 : scb_sec - 1;
                        else scb_msec = (scb_msec == 0) ? 99 : scb_msec - 1;
                    end
                end
            end
            tr.display("scb");
            // 한 사이클 판단 끝났으므로 다음 트랜잭션 요청
            ->gen_next_ev;
        end
    endtask
endclass

// --- Environment ---
class environment;
    generator               gen;
    driver                  drv;
    monitor                 mon;
    scoreboard              scb;

    mailbox #(transaction)  g2d_mbox,    m2s_mbox;
    event                   gen_next_ev;
    virtual watch_interface watch_if;

    function new(virtual watch_interface watch_if);
        g2d_mbox = new();
        m2s_mbox = new();
        gen = new(g2d_mbox, gen_next_ev);
        drv = new(g2d_mbox, watch_if);
        mon = new(m2s_mbox, watch_if);
        scb = new(m2s_mbox, gen_next_ev);
    endfunction

    task run();
        drv.preset();
        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #100;
        $display("\n****************************");
        $display("** total try   = %3d      **", scb.try_cnt);
        $display("** pass count  = %3d      **", scb.pass_cnt);
        $display("** fail count  = %3d      **", scb.fail_cnt);
        $display("****************************\n");
        $finish;
    endtask
endclass

// --- Top Module ---
module tb_watch_sv ();
    logic clk = 0;
    always #5 clk = ~clk;

    watch_interface watch_if (clk);
    environment env;

    // DUT 인스턴스
    watch_datapath dut (
        .clk(clk),
        .reset(watch_if.reset),
        .left(watch_if.left),
        .right(watch_if.right),
        .up(watch_if.up),
        .down(watch_if.down),
        .sw_2(watch_if.sw_2),
        .msec(watch_if.msec),
        .sec(watch_if.sec),
        .min(watch_if.min),
        .hour(watch_if.hour)
    );

    initial begin
        env = new(watch_if);
        env.run();
    end
endmodule
*/
