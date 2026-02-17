module axi_write_path #(
  parameter int NO_OF_MASTERS=4,
  parameter int ADDR_WIDTH=32,
  parameter int DATA_WIDTH=64,
  parameter int ID_WIDTH=4,           // assuming one bit for each master
  parameter int MAX_OUTSTANDING=4     // max outstanding txns per master
)(
  input  logic aclk,
  input  logic aresetn,
  
  // Master AW channel
  input  logic [NO_OF_MASTERS-1:0] m_awvalid,
  output logic [NO_OF_MASTERS-1:0] m_awready,
  input  logic [ADDR_WIDTH-1:0] m_awaddr[NO_OF_MASTERS],
  input  logic [ID_WIDTH-1:0] m_awid [NO_OF_MASTERS],
  input  logic [7:0] m_awlen [NO_OF_MASTERS],
  input  logic [2:0] m_awsize [NO_OF_MASTERS],
  input  logic [1:0] m_awburst [NO_OF_MASTERS],
  
  // Master W channel
  input  logic [NO_OF_MASTERS-1:0] m_wvalid,
  output logic [NO_OF_MASTERS-1:0] m_wready,
  input  logic [DATA_WIDTH-1:0] m_wdata [NO_OF_MASTERS],
  input  logic [(DATA_WIDTH/8)-1:0] m_wstrb [NO_OF_MASTERS],
  input  logic [NO_OF_MASTERS-1:0] m_wlast,
  
  // Master B channel
  output logic [NO_OF_MASTERS-1:0] m_bvalid,
  input  logic [NO_OF_MASTERS-1:0] m_bready,
  output logic [ID_WIDTH-1:0] m_bid [NO_OF_MASTERS],
  output logic [1:0] m_bresp [NO_OF_MASTERS],
  
  // Interface to Cache (for forwarding purpose)
  output logic cache_addr_valid [NO_OF_MASTERS],
  output logic [ADDR_WIDTH-1:0] cache_addr [NO_OF_MASTERS],
  output logic [ID_WIDTH-1:0] cache_id [NO_OF_MASTERS],
  output logic [7:0] cache_len [NO_OF_MASTERS],
  output logic [2:0] cache_size [NO_OF_MASTERS],
  output logic [1:0] cache_burst [NO_OF_MASTERS],
  
  output logic cache_data_valid [NO_OF_MASTERS],
  output logic [DATA_WIDTH-1:0] cache_data [NO_OF_MASTERS],
  output logic [(DATA_WIDTH/8)-1:0] cache_strb [NO_OF_MASTERS],
  output logic cache_data_last [NO_OF_MASTERS],
  
  input  logic cache_hit [NO_OF_MASTERS],
  input  logic cache_miss [NO_OF_MASTERS],
  input  logic cache_complete [NO_OF_MASTERS],
  input  logic cache_resp_valid [NO_OF_MASTERS],
  input  logic [1:0] cache_resp [NO_OF_MASTERS],
  input  logic [ID_WIDTH-1:0] cache_resp_id [NO_OF_MASTERS]
);

  localparam int master_id_w=$clog2(NO_OF_MASTERS);
  localparam int MID_W=master_id_w;

  //driven by Task 2(AW forward)
  logic wr_req_valid [NO_OF_MASTERS];
  logic [ADDR_WIDTH-1:0] wr_req_addr [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0] cache_id_fwd [NO_OF_MASTERS];  
  logic [7:0] wr_req_len [NO_OF_MASTERS];
  logic [2:0] wr_req_size [NO_OF_MASTERS];
  logic [1:0] wr_req_burst [NO_OF_MASTERS];

  //driven by Task 3(W forward)
  logic wr_data_valid [NO_OF_MASTERS];
  logic [DATA_WIDTH-1:0] wr_data [NO_OF_MASTERS];
  logic [(DATA_WIDTH/8)-1:0] wr_strb [NO_OF_MASTERS];
  logic wr_data_last [NO_OF_MASTERS];

  // input from cache,used by Task 1 for release logic)
  logic wr_cache_hit [NO_OF_MASTERS];
  logic wr_cache_miss [NO_OF_MASTERS];

  // driven by Task 6 ROB,used by Task 4(Response generation)
  logic wr_resp_valid [NO_OF_MASTERS];
  logic [1:0] wr_resp [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0] wr_req_id [NO_OF_MASTERS];

  // driven by Task 6,used by Task 5 scoreboard
  logic rob_retire [NO_OF_MASTERS];

  //Indicates write is in progress
  logic  w_active [NO_OF_MASTERS];
 
  
  // AW forward: internal → output ports
  genvar p;
  generate
    for (p = 0; p < NO_OF_MASTERS; p++) 
       begin : G_PORT_WIRE
        assign cache_addr_valid[p]=wr_req_valid[p];
        assign cache_addr[p]=wr_req_addr[p];
        assign cache_id[p]=cache_id_fwd[p]; 
         
        assign cache_len[p]=wr_req_len[p];
        assign cache_size[p]=wr_req_size[p];
        assign cache_burst[p]=wr_req_burst[p];

        assign cache_data_valid[p]=wr_data_valid[p];
        assign cache_data[p]=wr_data[p];
        assign cache_strb[p]=wr_strb[p];
        assign cache_data_last[p]=wr_data_last[p];

        assign wr_cache_hit[p]=cache_hit[p];
        assign wr_cache_miss[p]=cache_miss[p];
    end
  endgenerate

  //Task 1 ARBITRATION LOGIC
  logic aw_arb_busy;
  logic [master_id_w-1:0] aw_granted_master;
  logic [master_id_w-1:0] aw_rr_ptr;
  logic [NO_OF_MASTERS-1:0] aw_grant;   // one-hot signal
  
  // Round-robin arbitration
  always_ff @(posedge aclk or negedge aresetn) 
    begin
      if (!aresetn) 
        begin
          aw_rr_ptr<=0;
          aw_arb_busy<=1'b0;
          aw_granted_master<='0;
        end 
      else 
        begin
         // Grant release logic 
         if (aw_arb_busy && wr_req_valid[aw_granted_master] &&  (wr_cache_hit[aw_granted_master] || wr_cache_miss[aw_granted_master])) 
          begin
            aw_arb_busy <= 1'b0;
          end     
         // Grant new master logic
         if (!aw_arb_busy && (|aw_grant)) 
           begin
            for (int i = 0; i < NO_OF_MASTERS; i++) 
             begin
              if (aw_grant[i]) 
               begin
                aw_granted_master<=MID_W'(i);
                aw_arb_busy<=1'b1;
                aw_rr_ptr<=MID_W'((i + 1) % NO_OF_MASTERS);
                break;
               end
             end
           end
      end
    end
  
  always_comb 
    begin
     aw_grant = '0;
      if (!aw_arb_busy) 
        begin
         for (int k=0;k<NO_OF_MASTERS;k++) 
           begin
            int idx = (aw_rr_ptr + k) % NO_OF_MASTERS;
             if (m_awvalid[idx] && !sb_full[idx]) 
               begin  
                aw_grant[idx] = 1'b1;
                break;
               end
           end
        end
    end

  //TASK2 AW channel signal forwarding
  genvar m;
  generate
    for (m=0;m<NO_OF_MASTERS;m++) 
      begin : G_AW_FORWARD
      always_comb 
        begin
         if (aw_grant[m]||(aw_arb_busy && aw_granted_master == MID_W'(m))) 
           begin
             wr_req_valid[m]=m_awvalid[m];
             wr_req_addr[m]=m_awaddr[m];
             cache_id_fwd[m]=m_awid[m];
             wr_req_len[m]=m_awlen[m];
             wr_req_size[m]=m_awsize[m];
             wr_req_burst[m]=m_awburst[m];
             m_awready[m]=1'b1;
           end 
         else 
           begin
             wr_req_valid[m]=1'b0;
             wr_req_addr[m]='0;
             cache_id_fwd[m]='0;
             wr_req_len[m]='0;
             wr_req_size[m]='0;
             wr_req_burst[m]='0;
             m_awready[m]=1'b0;
           end
        end
      end
  endgenerate
  
  //TASK3 W_ACTIVE logic and W channel signal forwarding
  generate
    for (m=0;m<NO_OF_MASTERS;m++) 
      begin : G_W_ACTIVE
        always_ff @(posedge aclk or negedge aresetn) 
          begin
           if (!aresetn) 
             begin
              w_active[m]<=1'b0;
             end 
           else 
             begin
               if (aw_grant[m])                                          
                 w_active[m]<=1'b1;
               else if (w_active[m] && m_wvalid[m] && m_wlast[m]) 
                 w_active[m]<=1'b0;
             end
          end
      end
  endgenerate

 generate
   for (m=0;m<NO_OF_MASTERS;m++) 
      begin : G_W_FORWARD
        always_comb 
          begin
           if (w_active[m]) 
             begin  
              wr_data_valid[m]=m_wvalid[m];
              wr_data[m]=m_wdata[m];
              wr_strb[m]=m_wstrb[m];
              wr_data_last[m]=m_wlast[m];
              m_wready[m]=1'b1;
             end 
           else 
             begin
              wr_data_valid[m]=1'b0;
              wr_data[m]='0;
              wr_strb[m]='0;
              wr_data_last[m]=1'b0;
              m_wready[m]=1'b0;
             end
          end
      end
 endgenerate
  
 //TASK4 Response forward to interface
  generate
    for (m=0;m<NO_OF_MASTERS; m++) 
      begin : G_B_RESPONSE
        always_comb 
         begin
          if (wr_resp_valid[m]) 
           begin
            m_bvalid[m]=1'b1;
            m_bid[m]=wr_req_id[m];   // Both ID and response come from ROB(Task 6)
            m_bresp[m]=wr_resp[m];    
           end 
          else 
           begin
            m_bvalid[m]=1'b0;
            m_bid[m]='0;
            m_bresp[m]=2'b00;
           end
         end
      end
  endgenerate
  
 //TASK 5 Outstanding transactions handling and storing logic
  typedef struct packed {
    logic [ID_WIDTH-1:0] id;
    logic valid;
    logic done;
    logic [1:0] resp;
    }sb_entry_t;

  sb_entry_t scoreboard [NO_OF_MASTERS][MAX_OUTSTANDING];
  logic [$clog2(MAX_OUTSTANDING)-1:0] sb_wr_ptr [NO_OF_MASTERS];   //points to free slot
  logic [$clog2(MAX_OUTSTANDING)-1:0] sb_count [NO_OF_MASTERS];    //returns number of entries
  logic [$clog2(MAX_OUTSTANDING)-1:0] rob_retire_idx [NO_OF_MASTERS];  //to clear entry and give response 
  logic sb_full [NO_OF_MASTERS];  //used by arbitration

  generate
    for (m=0;m<NO_OF_MASTERS;m++) 
      begin : G_SCOREBOARD
        assign sb_full[m]=(sb_count[m]==MAX_OUTSTANDING);

        always_ff @(posedge aclk or negedge aresetn) 
          begin
           if (!aresetn) 
             begin
              sb_wr_ptr[m]<='0;
              sb_count[m]<='0;
              for (int i=0;i< MAX_OUTSTANDING;i++)
                scoreboard[m][i]<='0;
             end 
           else 
             begin

               // allocate an entry based on aw_grant[m]
               if (aw_grant[m] && !sb_full[m]) 
                 begin
                   scoreboard[m][sb_wr_ptr[m]]<=sb_entry_t'{
                                                               id:m_awid[m],
                                                               valid : 1'b1,
                                                               done  : 1'b0,
                                                               resp  : 2'b00
                                                             };
                      if (sb_wr_ptr[m]==MAX_OUTSTANDING-1)
                        sb_wr_ptr[m]<='0;
                      else
                        sb_wr_ptr[m]<=sb_wr_ptr[m]+1;

                   sb_count[m]<=sb_count[m]+1;
                 end

               //mark entry as done if cache responds with cache_resp_valid[m]
               if(cache_resp_valid[m]) 
                begin
                  for(int i=0;i<MAX_OUTSTANDING;i++) 
                    begin
                      if(scoreboard[m][i].valid && !scoreboard[m][i].done &&scoreboard[m][i].id == cache_resp_id[m])                           
                        begin
                          scoreboard[m][i].done<=1'b1;
                          scoreboard[m][i].resp<=cache_resp[m];
                          break;
                        end
                    end
                end

               //When ROB retires clear entry for the index specified by ROB
               if (rob_retire[m]) 
                begin
                  scoreboard[m][rob_retire_idx[m]]<='0;
                  sb_count[m]<=sb_count[m] - 1;
                end

             end
          end
      end
  endgenerate


  //TASK 6 Reordering responses of outstanding transactions
  generate
    for (m=0;m<NO_OF_MASTERS;m++) 
      begin : G_ROB
        always_comb 
          begin
           wr_resp_valid[m]=1'b0;
           wr_resp[m]=2'b00;
           wr_req_id[m]='0;
           rob_retire[m]=1'b0;
           rob_retire_idx[m]='0;

           for(int i=0;i<MAX_OUTSTANDING;i++) 
             begin
               
               if (scoreboard[m][i].valid && scoreboard[m][i].done) 
                 begin
                  logic earlier_same_id_pending;
                  earlier_same_id_pending = 1'b0;

                  // Check if earlier entry with SAME ID is still pending
                  for (int j = 0; j < MAX_OUTSTANDING; j++) 
                    begin
                      if (scoreboard[m][j].valid && !scoreboard[m][j].done && scoreboard[m][j].id == scoreboard[m][i].id) 
                        begin
                          if (j != i)
                            earlier_same_id_pending = 1'b1;
                        end
                    end

                  if(!earlier_same_id_pending) 
                    begin
                      wr_resp_valid[m]=1'b1;
                      wr_resp[m]=scoreboard[m][i].resp;
                      wr_req_id[m]=scoreboard[m][i].id;
                      rob_retire_idx[m]=i;

                      if (m_bready[m])
                        rob_retire[m] = 1'b1;

                      break;
                    end
                 end
             end
        end
      end
  endgenerate

endmodule
