`timescale 1 ns / 1 ps

module washing_machine_tb();
  
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////// DUT Signals ///////////////////////////////////////////////////// 
///////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  reg rst_n_tb;
  reg clk_tb;
  reg [1:0] clk_freq_tb;
  reg coin_in_tb;
  reg double_wash_tb;
  reg timer_pause_tb;
  wire wash_done_tb;

//////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////// Parameters /////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  localparam IDLE           = 3'b000,
             FILLING_WATER  = 3'b001,
             WASHING        = 3'b011,
             RINSING        = 3'b010,
             SPINNING       = 3'b110;
  
  localparam One_MHz    = 2'b00,
             Two_MHz    = 2'b01,
             Four_MHz   = 2'b10,
             Eight_MHz  = 2'b11;
             
  localparam numberOfCounts_2minutes_1MHz = 32'd120, 
             numberOfCounts_2minutes_2MHz = 32'd240,
             numberOfCounts_2minutes_4MHz = 32'd480,
             numberOfCounts_2minutes_8MHz = 32'd960,
             numberOfCounts_1minute_1MHz  = 32'd60,
             numberOfCounts_1minute_2MHz  = 32'd120,
             numberOfCounts_1minute_4MHz  = 32'd240,
             numberOfCounts_1minute_8MHz  = 32'd480,
             numberOfCounts_5minutes_1MHz = 32'd300,
             numberOfCounts_5minutes_2MHz = 32'd600,
             numberOfCounts_5minutes_4MHz = 32'd1200,
             numberOfCounts_5minutes_8MHz = 32'd2400;
             
//////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////// Variables //////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
             
  reg [9:0] Tperiod;
  integer frequency;
  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////// initial block ////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  initial
    begin
      
      // Dump (save) the waveforms
      $dumpfile("washing_machine.vcd");
      $dumpvars;
      
      for(frequency = One_MHz; frequency <= Eight_MHz; frequency = frequency + 'd1)
        begin
          
          // Signals initialization
          initialization(frequency);
          
          // Reset
          reset();
      
          // Test case 1: Check that as long as rst_n is low (even if a coin is deposited), the machine is in the IDLE state.
          test_case_1();
      
          // Test case 2: Check that a cycle starts only when a coin is deposited
          test_case_2();
        
          // Test case 3: Check that the filling water phase takes 2 minutes. To reduce the simulation time, 
          // we will divide all the required number of counts (i.e. counter cycles) by 10e6.
          test_case_3();
      
          // Test case 4: Check that the washing phase takes 5 minutes. To reduce the simulation time, 
          // we will divide all the required number of counts (i.e. counter cycles) by 10e6.
     	    test_case_4();
      
          // Test case 5: Check that the rinsing phase takes 2 minutes. To reduce the simulation time, 
          // we will divide all the required number of counts (i.e. counter cycles) by 10e6.
          test_case_5();
      
          // Test case 6: Check that the spinning phase takes 1 minute. To reduce the simulation time, 
          // we will divide all the required number of counts (i.e. counter cycles) by 10e6.
          test_case_6();
      
          // Test case 7: Check that the output wash_done flag is set after the spinning phase is completed and
          // remains high until coin_in is set again.
          test_case_7();
      
          // Test case 8: Check the workability of the double wash option and that washing and rinsing stages
          // are repeated when double_wash is high.
          test_case_8();
      
          // Test case 9: Check the workability of the timer pause option and that the spinning phase is paused
          // as long as the timer_pause input is set
          test_case_9();
      
          // Test case 10: Check that the timer pause option is only available in the spinning state only and that
          // the machine does not respond to it in any other state
          test_case_10(); 
          
        end
      $finish;
    end
  
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////// TASKS //////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////

  task initialization(
  input [1:0] operatingFrequency  
  );
    begin
      clk_tb = 1'b0;
      coin_in_tb = 1'b0;
      double_wash_tb = 1'b0;
      timer_pause_tb = 1'b0;
      case(operatingFrequency)
        One_MHz:
          begin
            clk_freq_tb = One_MHz;
            Tperiod = 'd1000;
          end
        Two_MHz:
          begin
            clk_freq_tb = Two_MHz;
            Tperiod = 'd500;
          end
        Four_MHz:
          begin
            clk_freq_tb = Four_MHz;
            Tperiod = 'd250;
          end
        Eight_MHz:
          begin
            clk_freq_tb = Eight_MHz;
            Tperiod = 'd125;
          end
      endcase
    end
  endtask
  
  task reset;
    begin
      rst_n_tb = 'd1;
      #1
      rst_n_tb = 'd0;
      #1
      rst_n_tb = 'd1;
    end
  endtask 
  
  task test_case_1;
    begin
      $display("Test case 1 running");
      coin_in_tb = 1'b1;
      rst_n_tb = 1'b0;
      #(Tperiod)
      if( DUT.current_state == IDLE )
        begin
          $display("Test case 1 passed");
        end
      else
        begin
          $display("Test case 1 failed");
        end
    end
  endtask
  
  task test_case_2;
    begin
      $display("Test case 2 running");
      rst_n_tb = 1'b1;
      coin_in_tb = 1'b1;
      #(Tperiod)
      if( DUT.current_state == FILLING_WATER )
        $display("Test case 2 passed");
      else
        $display("Test case 2 failed");
    end
  endtask
  
  task test_case_3;
    begin
      $display("Test case 3 running");
      delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
      if( DUT.current_state == WASHING)
        begin
          $display("Test case 3 passed");
        end
      else
        begin
          $display("Test case 3 failed");
        end
	   end
  endtask
  
  task test_case_4;
    begin
      $display("Test case 4 running");
      delay(numberOfCounts_5minutes_1MHz, numberOfCounts_5minutes_2MHz, numberOfCounts_5minutes_4MHz, numberOfCounts_5minutes_8MHz);
      if( DUT.current_state == RINSING)
        begin
          $display("Test case 4 passed");
        end
      else
        begin
          $display("Test case 4 failed");
        end
	   end
  endtask
  
  task test_case_5;
    begin
      $display("Test case 5 running");
      delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
      if( DUT.current_state == SPINNING)
        begin
          $display("Test case 5 passed");
        end
      else
        begin
          $display("Test case 5 failed");
        end
	   end
  endtask
  
  task test_case_6;
    begin
      $display("Test case 6 running");
      delay(numberOfCounts_1minute_1MHz, numberOfCounts_1minute_2MHz, numberOfCounts_1minute_4MHz, numberOfCounts_1minute_8MHz);
      if( DUT.current_state == IDLE)
        begin
          $display("Test case 6 passed");
        end
      else
        begin
          $display("Test case 6 failed");
        end
    end
  endtask
  
  task test_case_7;
    begin
      $display("Test case 7 running");
      coin_in_tb = 1'b0;
      #(Tperiod * 5);
      if(wash_done_tb == 1'b1)
        begin
          coin_in_tb = 1'b1;
          #(Tperiod);
          if(wash_done_tb == 1'b0)
            begin
              $display("Test case 7 passed");
            end
          else
            begin
              $display("Test case 7 failed");
            end
        end
      else
        begin
          $display("Test case 7 failed");
        end
    end
  endtask
  
  task test_case_8;
    begin
      $display("Test case 8 running");
      double_wash_tb = 'd1;
      delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
      // Now filling water is over
      delay(numberOfCounts_5minutes_1MHz, numberOfCounts_5minutes_2MHz, numberOfCounts_5minutes_4MHz, numberOfCounts_5minutes_8MHz);
      // Now first washing is over
      delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
      // Now first rinsing is over
      if(DUT.current_state == WASHING)
        begin
          delay(numberOfCounts_5minutes_1MHz, numberOfCounts_5minutes_2MHz, numberOfCounts_5minutes_4MHz, numberOfCounts_5minutes_8MHz);
          // Now second washing is over
          if(DUT.current_state == RINSING)
            begin
              delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
              // Now second rinsing is over
              if(DUT.current_state == SPINNING)
                begin
                  $display("Test case 8 passed");
                end
              else
                begin
                  $display("Test case 8 failed");
                end
            end
          else
            begin
              $display("Test case 8 failed");
            end
        end
      else  
        begin
          $display("Test case 8 failed");
        end
    end
  endtask
  
  task test_case_9;
    begin
      $display("Test case 9 running");
      timer_pause_tb = 1'b1;
      delay(numberOfCounts_1minute_1MHz, numberOfCounts_1minute_2MHz, numberOfCounts_1minute_4MHz, numberOfCounts_1minute_8MHz);
      if(DUT.current_state == SPINNING)
        begin
          timer_pause_tb = 1'b0;
          delay(numberOfCounts_1minute_1MHz, numberOfCounts_1minute_2MHz, numberOfCounts_1minute_4MHz, numberOfCounts_1minute_8MHz);
          if(DUT.current_state == IDLE)
            begin
              $display("Test case 9 passed");
            end
          else
            begin
              $display("Test case 9 failed");
            end
        end
      else
        begin
          $display("Test case 9 failed");
        end
    end
  endtask
  
  task test_case_10;
    begin
      double_wash_tb = 1'b0;
      #(Tperiod);
      $display("Test case 10 running");
      timer_pause_tb = 1'b1;
      delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
      if(DUT.current_state == WASHING)
        begin
          delay(numberOfCounts_5minutes_1MHz, numberOfCounts_5minutes_2MHz, numberOfCounts_5minutes_4MHz, numberOfCounts_5minutes_8MHz);
          if(DUT.current_state == RINSING)
            begin
              delay(numberOfCounts_2minutes_1MHz, numberOfCounts_2minutes_2MHz, numberOfCounts_2minutes_4MHz, numberOfCounts_2minutes_8MHz);
              if(DUT.current_state == SPINNING)
                begin
                  $display("Test case 10 passed");
                  timer_pause_tb = 1'b0;
                  delay(numberOfCounts_1minute_1MHz, numberOfCounts_1minute_2MHz, numberOfCounts_1minute_4MHz, numberOfCounts_1minute_8MHz);                  
                end
              else
                begin
                  $display("Test case 10 failed");
                end
            end
          else
            begin
              $display("Test case 10 failed");
            end
        end
      else
        begin
          $display("Test case 10 failed");
        end
    end
  endtask
  
  task delay(
    input [31:0]  numberOfCounts_1MHz,
    input [31:0]  numberOfCounts_2MHz,
    input [31:0]  numberOfCounts_4MHz,
    input [31:0]  numberOfCounts_8MHz
  );
    begin  
      case(clk_freq_tb)
        One_MHz:
          begin
            #(numberOfCounts_1MHz * Tperiod);
          end
        Two_MHz:
          begin
            #(numberOfCounts_2MHz * Tperiod);
          end
        Four_MHz:
          begin
            #(numberOfCounts_4MHz * Tperiod);
          end
        Eight_MHz:
          begin
            #(numberOfCounts_8MHz * Tperiod);
          end
      endcase
    end
  endtask
  
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////// Clock Generator ////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  always
    #(Tperiod/2.0) clk_tb = ~clk_tb;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////// DUT Instantation ////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
      
  washing_machine DUT(
  .rst_n(rst_n_tb),
  .clk(clk_tb),
  .clk_freq(clk_freq_tb),
  .coin_in(coin_in_tb),
  .double_wash(double_wash_tb),
  .timer_pause(timer_pause_tb),
  .wash_done(wash_done_tb)
  );
  
endmodule
