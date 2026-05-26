`timescale 1ns / 1ps

interface stopwatch_interface (
    input logic clk
);
    logic       reset;
    logic       mode;
    logic       clear;
    logic       run_stop;
    logic [6:0] msec;
    logic [5:0] sec;
    logic [5:0] min;
    logic [4:0] hour;

    property p_reset_check;
        @(posedge clk) reset |=> (msec == 0 && sec == 0 && min == 0 && hour == 0);
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

endinterface  //stopwatch_if

class transaction;

    rand bit       mode;
    rand bit       clear;
    rand bit       run_stop;
    logic          reset;
    logic    [6:0] msec;
    logic    [5:0] sec;
    logic    [5:0] min;
    logic    [4:0] hour;

    constraint run_stop_cons {
        run_stop dist {
            1 := 70,
            0 := 30
        };
    }

    constraint clear_cons {
        clear dist {
            1 := 20,
            0 := 80
        };
    }

    function void display(string name);
        $display(
            "%t : [%s] mode = %b, clear = %b, run_stop = %b, msec = %d, sec = %d, min = %d, hour = %d",
            $time, name, mode, clear, run_stop, msec, sec, min, hour);
    endfunction  //display()
endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;
    virtual stopwatch_interface stopwatch_if;

    parameter F_COUNT = 100_000_000 / 1000000;  //100Hz tick

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev,
                 virtual stopwatch_interface stopwatch_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            repeat (3 * F_COUNT) begin
                @(negedge (stopwatch_if.clk));  //20msec에 한 번씩 랜덤값 생성, 전달
            end
        end
    endtask
endclass

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual stopwatch_interface stopwatch_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual stopwatch_interface stopwatch_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task preset();
        #1;
        stopwatch_if.reset = 1;
        stopwatch_if.mode = 0;
        stopwatch_if.clear = 0;
        stopwatch_if.run_stop = 0;
        @(negedge (stopwatch_if.clk));
        @(negedge (stopwatch_if.clk));
        stopwatch_if.reset = 0;
        @(negedge (stopwatch_if.clk));
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(posedge (stopwatch_if.clk));
            #1;
            stopwatch_if.mode     = tr.mode;
            stopwatch_if.clear    = tr.clear;
            stopwatch_if.run_stop = tr.run_stop;
            tr.display("drv");
        end
    endtask
endclass

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual stopwatch_interface stopwatch_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual stopwatch_interface stopwatch_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task run();
        forever begin
            tr = new();
            @(negedge (stopwatch_if.clk));
            tr.reset    = stopwatch_if.reset;
            tr.mode     = stopwatch_if.mode;
            tr.clear    = stopwatch_if.clear;
            tr.run_stop = stopwatch_if.run_stop;
            tr.msec     = stopwatch_if.msec;
            tr.sec      = stopwatch_if.sec;
            tr.min      = stopwatch_if.min;
            tr.hour     = stopwatch_if.hour;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    virtual stopwatch_interface stopwatch_if;
    int try_cnt, pass_cnt, fail_cnt;

    parameter F_COUNT = 100_000_000 / 1000000;  //10ms
    logic [$clog2(F_COUNT)-1:0] scb_tick_cnt;
    logic scb_tick_100hz;  //1ms

    logic [6:0] scb_msec;
    logic [5:0] scb_sec;
    logic [5:0] scb_min;
    logic [4:0] scb_hour;

    bit pre_mode;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev,
                 virtual stopwatch_interface stopwatch_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task stopwatch();
        scb_tick_cnt   = 0;
        scb_tick_100hz = 0;
        scb_msec       = 0;
        scb_sec        = 0;
        scb_min        = 0;
        scb_hour       = 0;
        pre_mode       = stopwatch_if.mode;
        $display("%t : stopwatch start", $time);
        forever begin  //100Hz tick counter
            @(posedge (stopwatch_if.clk)); //posedge
            if (stopwatch_if.reset || stopwatch_if.clear) begin
                scb_tick_cnt   = 0;
                scb_tick_100hz = 0;
                scb_msec       = 0;
                scb_sec        = 0;
                scb_min        = 0;
                scb_hour       = 0;
            end else begin
                //Time Count
                if (stopwatch_if.run_stop) begin
                    pre_mode   = stopwatch_if.mode;
                    if (scb_tick_cnt == F_COUNT) begin  //100hz tick count
                        scb_tick_100hz = 1;
                        scb_tick_cnt   = 1;
                        if (stopwatch_if.mode == 0) begin  //up count
                            if (scb_msec == 99) begin  //msec count
                                scb_msec = 0;
                                if (scb_sec == 59) begin  //sec count
                                    scb_sec = 0;
                                    if (scb_min == 59) begin  //min count
                                        scb_min = 0;
                                        if (scb_hour == 23) begin
                                            scb_hour = 0;
                                        end else scb_hour++;
                                    end else scb_min++;
                                end else scb_sec++;
                            end else begin
                                scb_msec++;
                                $display("msec UP!");
                            end
                        end else begin  //down count
                            if (scb_msec == 0) begin  //msec count
                                scb_msec = 99;
                                if (scb_sec == 0) begin  //sec count
                                    scb_sec = 59;
                                    if (scb_min == 0) begin  //min count
                                        scb_min = 59;
                                        if (scb_hour == 0) begin
                                            scb_hour = 23;
                                        end else scb_hour--;
                                    end else scb_min--;
                                end else scb_sec--;
                            end else scb_msec--;
                        end
                    end else begin
                        scb_tick_100hz = 0;
                        scb_tick_cnt++;

                    end
                    /*
                    @(negedge (stopwatch_if.clk)); 
                    if (~stopwatch_if.run_stop) begin
                        scb_tick_cnt--;
                        if (scb_tick_cnt < 0) begin scb_tick_cnt = 100; end
                    end*/
                    /*
                    else if (pre_mode != stopwatch_if.mode)begin
                        scb_tick_cnt--;
                        if (scb_tick_cnt < 0) begin scb_tick_cnt = 100; end
                    end*/
                end
                $display("%t : 100hz Tick Count = %d", $time, scb_tick_cnt);
                //$display("%t : scb_msec = %d", $time, scb_msec);
                
            end
        end
    endtask

    task run();
        forever begin  //Check
            mon2scb_mbox.get(tr);  //negedge
            try_cnt++;
            if (tr.msec == scb_msec) begin
                if (tr.sec == scb_sec) begin
                    if (tr.min == scb_min) begin
                        if (tr.hour == scb_hour) begin
                            $display("%t: [PASS] Time = %d : %d : %d : %d",
                                     $time, tr.hour, tr.min, tr.sec, tr.msec);
                            pass_cnt++;
                        end else
                            $display(
                                "%t: Hour Unmatched! tr.hour = %d, scb_hour = %d",
                                $time,
                                tr.hour,
                                scb_hour
                            );
                    end else
                        $display(
                            "%t: Minute Unmatched! tr.min = %d, scb_min = %d",
                            $time,
                            tr.min,
                            scb_min
                        );
                end else
                    $display(
                        "%t: Sec Unmatched! tr.sec = %d, scb_sec = %d",
                        $time,
                        tr.sec,
                        scb_sec
                    );
            end else
                $display(
                    "%t: Msec Unmatched! tr.msec = %d, scb_msec = %d",
                    $time,
                    tr.msec,
                    scb_msec
                );
            tr.display("scb");
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

    event gen_next_ev;

    function new(virtual stopwatch_interface stopwatch_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev, stopwatch_if);
        drv = new(gen2drv_mbox, stopwatch_if);
        mon = new(mon2scb_mbox, stopwatch_if);
        scb = new(mon2scb_mbox, gen_next_ev, stopwatch_if);
    endfunction

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.stopwatch();
            scb.run();
        join_any
        #10;

        $display("____________________________");
        $display("**   Stopwatch verify     **");
        $display("****************************");
        $display("** total try count = %3d **", scb.try_cnt);
        $display("** pass count = %3d      **", scb.pass_cnt);
        $display("** fail count = %3d      **", (scb.try_cnt - scb.pass_cnt));
        $display("****************************");
        $stop;
    endtask
endclass

module tb_stopwatch_sv ();

    logic clk;
    stopwatch_interface stopwatch_if (clk);
    environment env;

    stopwatch_datapath dut (
        .clk     (clk),
        .reset   (stopwatch_if.reset),
        .mode    (stopwatch_if.mode),
        .clear   (stopwatch_if.clear),
        .run_stop(stopwatch_if.run_stop),
        .msec    (stopwatch_if.msec),
        .sec     (stopwatch_if.sec),
        .min     (stopwatch_if.min),
        .hour    (stopwatch_if.hour)

    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(stopwatch_if);

        env.run();

    end

endmodule
