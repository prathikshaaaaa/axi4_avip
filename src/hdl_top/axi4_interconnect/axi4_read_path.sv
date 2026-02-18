module axi_read_path #(
  parameter int NO_OF_MASTERS   = 4,
  parameter int ADDR_WIDTH      = 32,
  parameter int DATA_WIDTH      = 64,
  parameter int ID_WIDTH        = 4,
  parameter int MAX_OUTSTANDING = 4
)(
  input  logic aclk,
  input  logic aresetn,
  input  logic [NO_OF_MASTERS-1:0]         m_arvalid,
  output logic [NO_OF_MASTERS-1:0]         m_arready,
  input  logic [ADDR_WIDTH-1:0]            m_araddr      [NO_OF_MASTERS],
  input  logic [ID_WIDTH-1:0]              m_arid        [NO_OF_MASTERS],
  input  logic [7:0]                       m_arlen       [NO_OF_MASTERS],
  input  logic [2:0]                       m_arsize      [NO_OF_MASTERS],
  input  logic [1:0]                       m_arburst     [NO_OF_MASTERS],
  input  logic [NO_OF_MASTERS-1:0]         m_rready,
  input  logic                             rd_ready      [NO_OF_MASTERS], 
  output logic [NO_OF_MASTERS-1:0]         m_rvalid,
  output logic [DATA_WIDTH-1:0]            m_rdata       [NO_OF_MASTERS],
  output logic [ID_WIDTH-1:0]              m_rid         [NO_OF_MASTERS],
  output logic [1:0]                       m_rresp       [NO_OF_MASTERS],
  output logic [NO_OF_MASTERS-1:0]         m_rlast,
  output logic                             rd_req_valid  [NO_OF_MASTERS],
  output logic [ADDR_WIDTH-1:0]            rd_req_addr   [NO_OF_MASTERS],
  output logic [ID_WIDTH-1:0]              rd_req_id     [NO_OF_MASTERS],
  output logic [7:0]                       rd_req_len    [NO_OF_MASTERS],
  output logic [2:0]                       rd_req_size   [NO_OF_MASTERS],
  output logic [1:0]                       rd_req_burst  [NO_OF_MASTERS],
  input  logic                             rd_cache_hit  [NO_OF_MASTERS],
  input  logic                             rd_cache_miss [NO_OF_MASTERS],
  input  logic [DATA_WIDTH-1:0]            rd_cache_data [NO_OF_MASTERS],
  input  logic [ID_WIDTH-1:0]              rd_data_id    [NO_OF_MASTERS],
  input  logic                             rd_data_valid [NO_OF_MASTERS],
  input  logic                             rd_data_last  [NO_OF_MASTERS]
);
  localparam int MID_W = $clog2(NO_OF_MASTERS);
  logic ar_arb_busy;
  logic [MID_W-1:0] ar_granted_master;
  logic [MID_W-1:0] ar_rr_ptr;
  logic [NO_OF_MASTERS-1:0] ar_grant;
  typedef struct packed {
    logic [ID_WIDTH-1:0] id;
    logic valid;
    logic done;
    logic [DATA_WIDTH-1:0] data;
    logic last;
  } rd_sb_entry_t;
  rd_sb_entry_t rd_scoreboard [NO_OF_MASTERS][MAX_OUTSTANDING];
  logic [$clog2(MAX_OUTSTANDING)-1:0] rd_sb_wr_ptr [NO_OF_MASTERS];
  logic [$clog2(MAX_OUTSTANDING)-1:0] rd_sb_rd_ptr [NO_OF_MASTERS];
  logic [$clog2(MAX_OUTSTANDING):0]   rd_sb_count  [NO_OF_MASTERS];
  logic rd_sb_full [NO_OF_MASTERS];
  logic rob_retire [NO_OF_MASTERS];
  logic [$clog2(MAX_OUTSTANDING)-1:0] rob_retire_idx [NO_OF_MASTERS];
  generate
    for (genvar m=0;m<NO_OF_MASTERS;m++) begin : G_SB_FULL
      assign rd_sb_full[m] = (rd_sb_count[m]==MAX_OUTSTANDING);
    end
  endgenerate
  always_ff @(posedge aclk or negedge aresetn) begin
    if(!aresetn) begin
      ar_rr_ptr <= '0;
      ar_arb_busy <= 1'b0;
      ar_granted_master <= '0;
    end else begin
      if(ar_arb_busy && m_arvalid[ar_granted_master] &&
         m_arready[ar_granted_master] )  
           ar_arb_busy <= 1'b0;
      if(!ar_arb_busy && (|ar_grant)) begin
        for(int i=0;i<NO_OF_MASTERS;i++) begin
          if(ar_grant[i]) begin
            ar_granted_master <= MID_W'(i);
            ar_arb_busy <= 1'b1;
            ar_rr_ptr <= MID_W'((i+1)%NO_OF_MASTERS);
            break;
          end
        end
      end
    end
  end
  always_comb begin
    ar_grant = '0;
    if(!ar_arb_busy) begin
      for(int k=0;k<NO_OF_MASTERS;k++) begin
        int idx; 
        idx = (ar_rr_ptr+k)%NO_OF_MASTERS;
        if(m_arvalid[idx] && !rd_sb_full[idx]) begin
          ar_grant[idx] = 1'b1;
          break;
        end
      end
    end
  end
  generate
    for(genvar m=0;m<NO_OF_MASTERS;m++) begin : G_AR_FORWARD
      always_comb begin
        if(ar_grant[m] || (ar_arb_busy && ar_granted_master==MID_W'(m))) begin
          rd_req_valid[m] = m_arvalid[m] && rd_ready[m]; 
          rd_req_addr[m]  = m_araddr[m];
          rd_req_id[m]    = m_arid[m];
          rd_req_len[m]   = m_arlen[m];
          rd_req_size[m]  = m_arsize[m];
          rd_req_burst[m] = m_arburst[m];
          m_arready[m]    = rd_ready[m]; 
        end else begin
          rd_req_valid[m] = 1'b0;
          rd_req_addr[m]  = '0;
          rd_req_id[m]    = '0;
          rd_req_len[m]   = '0;
          rd_req_size[m]  = '0;
          rd_req_burst[m] = '0;
          m_arready[m]    = 1'b0;
        end
      end
    end
  endgenerate
  generate
    for(genvar m=0;m<NO_OF_MASTERS;m++) begin : G_SCOREBOARD
      always_ff @(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin
          rd_sb_wr_ptr[m] <= '0;
          rd_sb_rd_ptr[m] <= '0;
          rd_sb_count[m]  <= '0;
          for(int i=0;i<MAX_OUTSTANDING;i++)
            rd_scoreboard[m][i] <= '0;
        end else begin
          if(m_arvalid[m] && m_arready[m]) begin  
            rd_scoreboard[m][rd_sb_wr_ptr[m]] <= rd_sb_entry_t'{id:m_arid[m], valid:1'b1, done:1'b0, data:'0, last:1'b0};
            rd_sb_wr_ptr[m] <= (rd_sb_wr_ptr[m]==MAX_OUTSTANDING-1)?'0:rd_sb_wr_ptr[m]+1;
            rd_sb_count[m] <= rd_sb_count[m]+1;
          end
          if(rd_data_valid[m]) begin
            for(int i=0;i<MAX_OUTSTANDING;i++) begin
              if(rd_scoreboard[m][i].valid && !rd_scoreboard[m][i].done &&
                 rd_scoreboard[m][i].id == rd_data_id[m] /* added-changed */ )
              begin
                   rd_scoreboard[m][i].data <= rd_cache_data[m];
                   rd_scoreboard[m][i].last <= rd_data_last[m];
                   if(rd_data_last[m])
                     rd_scoreboard[m][i].done <= 1'b1;
                   break;
              end
            end
          end
          if(rob_retire[m]) begin
            rd_scoreboard[m][rob_retire_idx[m]] <= '0;
            rd_sb_rd_ptr[m] <= (rd_sb_rd_ptr[m]==MAX_OUTSTANDING-1)?'0:rd_sb_rd_ptr[m]+1;
            rd_sb_count[m] <= rd_sb_count[m]-1;
          end
        end
      end
    end
  endgenerate
  generate
    for(genvar m=0;m<NO_OF_MASTERS;m++) begin : G_ROB
      always_comb begin
        m_rvalid[m]=1'b0;
        m_rdata[m]='0;
        m_rid[m]='0;
        m_rresp[m]=2'b00;
        m_rlast[m]=1'b0;
        rob_retire[m]=1'b0;
        rob_retire_idx[m]='0;
        for(int i=0;i<MAX_OUTSTANDING;i++) begin
          if(rd_scoreboard[m][i].valid && rd_scoreboard[m][i].done) begin
            logic earlier_pending;
            earlier_pending = 1'b0;
            for(int j=0;j<MAX_OUTSTANDING;j++) begin
              if(j!=i && rd_scoreboard[m][j].valid && !rd_scoreboard[m][j].done)
                earlier_pending = 1'b1;
            end
            if(!earlier_pending) begin
              m_rvalid[m]=1'b1;
              m_rdata[m]=rd_scoreboard[m][i].data;
              m_rid[m]=rd_scoreboard[m][i].id;
              m_rresp[m]=2'b00;
              m_rlast[m]=rd_scoreboard[m][i].last;
              if(m_rready[m] && m_rlast[m]) begin
                rob_retire[m]=1'b1;
                rob_retire_idx[m]=i;
              end
              break;
            end
          end
        end
      end
    end
  endgenerate
endmodule
