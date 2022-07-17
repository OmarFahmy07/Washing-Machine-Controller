//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Module ports list, declaration, and data type ///////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

module washing_machine(
  input wire rst_n,
  input wire clk,
  input wire [1:0] clk_freq,
  input wire coin_in,
  input wire double_wash,
  input wire timer_pause,
  output reg wash_done
  );
  
//////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////// Parameters /////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
  
  // Define states using gray encoding to reduce switching power
  localparam IDLE           = 3'b000,
             FILLING_WATER  = 3'b001,
             WASHING        = 3'b011,
             RINSING        = 3'b010,
             SPINNING       = 3'b110;

  // Define different frequencies as parameters for readability
  localparam One_MHz        = 2'b00,
             Two_MHz        = 2'b01,
             Four_MHz       = 2'b10,
             Eight_MHz      = 2'b11;
             
  // Define the number of counts required by the counter to reach specific time for each frequency
  localparam numberOfCounts_2minutes_1MHz = 32'd119, 
             numberOfCounts_2minutes_2MHz = 32'd239,
             numberOfCounts_2minutes_4MHz = 32'd479,
             numberOfCounts_2minutes_8MHz = 32'd959,
             numberOfCounts_1minute_1MHz  = 32'd59,
             numberOfCounts_1minute_2MHz  = 32'd119,
             numberOfCounts_1minute_4MHz  = 32'd239,
             numberOfCounts_1minute_8MHz  = 32'd479,
             numberOfCounts_5minutes_1MHz = 32'd299,
             numberOfCounts_5minutes_2MHz = 32'd599,
             numberOfCounts_5minutes_4MHz = 32'd1199,
             numberOfCounts_5minutes_8MHz = 32'd2399;
  
////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// Variables and Internal Connections ////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

  reg [2:0] current_state, next_state;
  reg [31:0] counter, counter_comb;
  reg timeout_flag;
  reg [1:0] number_of_washes;
  
////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// Sequential Procedural Blocks //////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////
  
    // Logic to support the "double wash" option. A counter number_of_washes is used to count the number of
    // washes in order to make 2 washes whenever the user requests a double wash.
    always@(posedge clk)
      begin
        // If a wash cycle is completed OR the reset button is pressed, reset the number of washes counter for the next
        // user to be able to use the "double wash" option
        if(current_state == IDLE)
          begin
            number_of_washes <= 'd0;
          end
        // If the washing phase is completed, increment the number of washes counter
        else if( (current_state == WASHING) && timeout_flag )
          begin
            number_of_washes <= number_of_washes + 'd1;
          end
      end  
    
  // Current state sequential logic
  always@(posedge clk or negedge rst_n)
    begin
      // If the reset button is pressed, go to the idle state asynchronously
      if(!rst_n)
        begin
          current_state <= IDLE;
        end
      // Otherwise, go to the state decided by the next state combinational logic
      else
        begin
          current_state <= next_state;
        end
    end
    
  // 32-bit counter sequential logic
  always@(posedge clk or negedge rst_n)
    begin
      // If the reset button is pressed, the counter is reset asynchronously
      if(!rst_n)
        begin
          counter <= 'd0;
        end
      // Otherwise, the counter is loaded with the value decided by the counter's combinational logic
      else
        begin
          counter <= counter_comb;
        end
    end

    
////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// Combinational Procedural Blocks ///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

  
  // Next state combinational logic
  always@(*)
    begin
      // Initial value to avoid unintentional latches
      next_state = IDLE;
      case(current_state)
        IDLE:
          begin
            // Begin the operation only when a coin is deposited
            if(coin_in)
              begin
                next_state = FILLING_WATER;
              end
            // Otherwise, remain IDLE
            else
              begin    
                next_state = current_state;
              end
          end
        FILLING_WATER:
          begin
            // Go to the next state (washing) when the filling water's duration (2 minutes) is over
            if(timeout_flag)
              begin
                next_state = WASHING;
              end
            // Otherwise, continue filling water
            else
              begin
                next_state = current_state;
              end
          end
        WASHING:
          begin
            // Go to the next phase (rinsing) when the washing's duration (5 minutes) is over
            if(timeout_flag)
              begin
                next_state = RINSING;
              end
            else
              begin
                // Otherwise, continue washing
                next_state = current_state;
              end
          end
        RINSING:
          begin
            if(timeout_flag)
              begin
                // when the rinsing's duration is over, check if the user is requesting a second wash
                if(double_wash)
                  begin
                    // Check the number_of_washes counter first. If we have done only 1 wash, then go to the 
                    // WASHING state for the second wash.
                    if(number_of_washes == 'd1)
                      begin
                        next_state = WASHING;
                      end
                    // Otherwise if the second wash is already done, go to the SPINNING state.
                    else
                      begin
                        next_state = SPINNING;
                      end
                  end
                // If no second wash is requested by the user, then go to the SPINNING state.
                else
                  begin
                    next_state = SPINNING;
                  end
              end
            // Otherwise, if the rinsing phase's duration is not over yet, remain in the rinsing state
            else
              begin
                next_state = current_state;
              end
          end
        SPINNING:
          begin
            // When the spinning phase is over (and accordingly the whole operation), return to IDLE state
            if(timeout_flag)
              begin
                next_state = IDLE;
              end
            // Otherwise, continue spinning
            else
              begin
                next_state = current_state;
              end
          end
        // A default case for any unexpected behavior and to also avoid any unintentional latches
        default:
          begin
            next_state = IDLE;
          end
      endcase
    end
    
  // Output combinational logic
  always@(*)
    begin
      // As long as the machine is not being used, the output wash_done is set indicating the availability of
      // the machine. When a user deposits a coin, the output wash_done is deasserted indicating that an 
      // operation is currently running (i.e. the machine is not available).
      if(current_state == IDLE)
        begin
          wash_done = 'd1;
        end
      else
        begin
          wash_done = 'd0;
        end
    end

  // 32-bit counter combinational logic
  always@(*)
    begin
      // Initial values to avoid unintentional latches
      counter_comb = 'd0;
      timeout_flag = 1'b0;
      case(current_state)
        IDLE:
        // Counter should not count in the IDLE state
          begin
            counter_comb = 'd0;
            timeout_flag = 1'b0;
          end
        FILLING_WATER:
        // Counter should count a number of counts equivalent to 2 minutes, which depends on the
        // clock frequency
          begin
            case(clk_freq)
              One_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_1MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Two_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_2MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Four_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_4MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Eight_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_8MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              default:
                begin
                  counter_comb = 'd0;
                  timeout_flag = 1'b0;
                end
            endcase
          end
        WASHING:
        // Counter should count a number of counts equivalent to 5 minutes, which depends on the clock
        // frequency
          begin
            case(clk_freq)
              One_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_5minutes_1MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Two_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_5minutes_2MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Four_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_5minutes_4MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Eight_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_5minutes_8MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              default:
                begin
                  counter_comb = 'd0;
                  timeout_flag = 1'b0;
                end
            endcase
          end
        RINSING:
        // Counter should count a number of counts equivalent to 2 minutes, which depends on the clock
        // frequency
          begin
            case(clk_freq)
              One_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_1MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Two_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_2MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Four_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_4MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Eight_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_2minutes_8MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              default:
                begin
                  counter_comb = 'd0;
                  timeout_flag = 1'b0;
                end
            endcase
          end
        SPINNING:
        // Counter should count a number of counts equivalent to 1 minute, which depends on the clock frequency
          begin
            case(clk_freq)
              One_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_1minute_1MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, if the user has requested to pause the timer, freeze the counter until timer_pause is deasserted
                  else if(timer_pause)
                    begin
                      counter_comb = counter;
                      timeout_flag = 1'b0;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Two_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_1minute_2MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, if the user has requested to pause the timer, freeze the counter until timer_pause is deasserted
                  else if(timer_pause)
                    begin
                      counter_comb = counter;
                      timeout_flag = 1'b0;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Four_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_1minute_4MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, if the user has requested to pause the timer, freeze the counter until timer_pause is deasserted
                  else if(timer_pause)
                    begin
                      counter_comb = counter;
                      timeout_flag = 1'b0;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              Eight_MHz:
                begin
                  // If the counter has reached the required number of counts, reset the counter and fire the timeout flag
                  if(counter == numberOfCounts_1minute_8MHz)
                    begin
                      counter_comb = 'd0;
                      timeout_flag = 1'b1;
                    end
                  // Otherwise, if the user has requested to pause the timer, freeze the counter until timer_pause is deasserted
                  else if(timer_pause)
                    begin
                      counter_comb = counter;
                      timeout_flag = 1'b0;
                    end
                  // Otherwise, increment the counter and keep the timeout flag deasserted
                  else
                    begin
                      counter_comb = counter + 'd1;
                      timeout_flag = 1'b0;
                    end
                end
              // A default case for any unexpected behavior and to avoid any unintentional latches
              default:
                begin
                  counter_comb = 'd0;
                  timeout_flag = 1'b0;
                end
            endcase
          end    
        default:
          begin
            counter_comb = 'd0;
            timeout_flag = 1'b0;
          end    
      endcase
    end 
      
endmodule
