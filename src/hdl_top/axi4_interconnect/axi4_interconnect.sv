`include "axi4_write_path.sv"
`include "axi4_read_path.sv"
`include "axi4_cache_controller.sv"
`include "../../globals/axi4_globals_pkg.sv"
import axi4_globals_pkg::*;

module axi_interconnect_cache
(
  input  logic aclk,
  input  logic aresetn,
  
  // Master interface
  axi_if.axiMasterInterconnectMP master_if [NO_OF_MASTERS],
  
  // Slave interfaces
  axi_if.axiSlaveInterconnectMP  slave_if  [NO_OF_SLAVES]
);

  //==========================================================================
  // LOCAL PARAMETERS
  //==========================================================================
  
  // Bit widths for indexing
  localparam int MID_W = (NO_OF_MASTERS <= 1) ? 1 : $clog2(NO_OF_MASTERS);
  localparam int SID_W = (NO_OF_SLAVES  <= 1) ? 1 : $clog2(NO_OF_SLAVES);
  
  // Cache parameters (from package)
  localparam int OFFSET_BITS = $clog2(CACHE_LINE_SIZE);
  localparam int INDEX_BITS  = $clog2(NUM_SETS);
  localparam int TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;

  //==========================================================================
  // SIGNAL DECLARATIONS
  //==========================================================================
  
  // --- Signals from Masters ---
  logic [NO_OF_MASTERS-1:0]        m_arvalid;
  logic [NO_OF_MASTERS-1:0]        m_arready;
  logic [ADDR_WIDTH-1:0]           m_araddr  [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             m_arid    [NO_OF_MASTERS];
  logic [7:0]                      m_arlen   [NO_OF_MASTERS];
  logic [2:0]                      m_arsize  [NO_OF_MASTERS];
  logic [1:0]                      m_arburst [NO_OF_MASTERS];
  
  logic [NO_OF_MASTERS-1:0]        m_rready;
  logic [NO_OF_MASTERS-1:0]        m_rvalid;
  logic [DATA_WIDTH-1:0]           m_rdata   [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             m_rid     [NO_OF_MASTERS];
  logic [1:0]                      m_rresp   [NO_OF_MASTERS];
  logic [NO_OF_MASTERS-1:0]        m_rlast;
  
  // --- Signals from Masters  ---
  logic [NO_OF_MASTERS-1:0]        m_awvalid;
  logic [NO_OF_MASTERS-1:0]        m_awready;
  logic [ADDR_WIDTH-1:0]           m_awaddr  [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             m_awid    [NO_OF_MASTERS];
  logic [7:0]                      m_awlen   [NO_OF_MASTERS];
  logic [2:0]                      m_awsize  [NO_OF_MASTERS];
  logic [1:0]                      m_awburst [NO_OF_MASTERS];
  
  logic [NO_OF_MASTERS-1:0]        m_wvalid;
  logic [NO_OF_MASTERS-1:0]        m_wready;
  logic [DATA_WIDTH-1:0]           m_wdata   [NO_OF_MASTERS];
  logic [(DATA_WIDTH/8)-1:0]       m_wstrb   [NO_OF_MASTERS];
  logic [NO_OF_MASTERS-1:0]        m_wlast;
  
  logic [NO_OF_MASTERS-1:0]        m_bready;
  logic [NO_OF_MASTERS-1:0]        m_bvalid;
  logic [ID_WIDTH-1:0]             m_bid     [NO_OF_MASTERS];
  logic [1:0]                      m_bresp   [NO_OF_MASTERS];
  
  // --- Signals to Slaves  ---
  logic [NO_OF_SLAVES-1:0]         s_arvalid;
  logic [NO_OF_SLAVES-1:0]         s_arready;
  logic [ADDR_WIDTH-1:0]           s_araddr  [NO_OF_SLAVES];
  logic [ID_WIDTH-1:0]             s_arid    [NO_OF_SLAVES];
  logic [7:0]                      s_arlen   [NO_OF_SLAVES];
  logic [2:0]                      s_arsize  [NO_OF_SLAVES];
  logic [1:0]                      s_arburst [NO_OF_SLAVES];
  
  logic [NO_OF_SLAVES-1:0]         s_rready;
  logic [NO_OF_SLAVES-1:0]         s_rvalid;
  logic [DATA_WIDTH-1:0]           s_rdata   [NO_OF_SLAVES];
  logic [ID_WIDTH-1:0]             s_rid     [NO_OF_SLAVES];
  logic [1:0]                      s_rresp   [NO_OF_SLAVES];
  logic [NO_OF_SLAVES-1:0]         s_rlast;
  
  logic [NO_OF_SLAVES-1:0]         s_awvalid;
  logic [NO_OF_SLAVES-1:0]         s_awready;
  logic [ADDR_WIDTH-1:0]           s_awaddr  [NO_OF_SLAVES];
  logic [ID_WIDTH-1:0]             s_awid    [NO_OF_SLAVES];
  logic [7:0]                      s_awlen   [NO_OF_SLAVES];
  logic [2:0]                      s_awsize  [NO_OF_SLAVES];
  logic [1:0]                      s_awburst [NO_OF_SLAVES];
  
  logic [NO_OF_SLAVES-1:0]         s_wvalid;
  logic [NO_OF_SLAVES-1:0]         s_wready;
  logic [DATA_WIDTH-1:0]           s_wdata   [NO_OF_SLAVES];
  logic [(DATA_WIDTH/8)-1:0]       s_wstrb   [NO_OF_SLAVES];
  logic [NO_OF_SLAVES-1:0]         s_wlast;
  
  logic [NO_OF_SLAVES-1:0]         s_bready;
  logic [NO_OF_SLAVES-1:0]         s_bvalid;
  logic [ID_WIDTH-1:0]             s_bid     [NO_OF_SLAVES];
  logic [1:0]                      s_bresp   [NO_OF_SLAVES];

  //==========================================================================
  // INTERFACE SIGNALS BETWEEN MODULES
  //==========================================================================
  
  // --- Read Path to Cache Interface ---
  logic                            rd_req_valid   [NO_OF_MASTERS];
  logic [ADDR_WIDTH-1:0]           rd_req_addr    [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             rd_req_id      [NO_OF_MASTERS];
  logic [7:0]                      rd_req_len     [NO_OF_MASTERS];
  logic [2:0]                      rd_req_size    [NO_OF_MASTERS];
  logic [1:0]                      rd_req_burst   [NO_OF_MASTERS];
  
  logic                            rd_ready       [NO_OF_MASTERS];
  logic                            rd_cache_hit   [NO_OF_MASTERS];
  logic                            rd_cache_miss  [NO_OF_MASTERS];
  logic [DATA_WIDTH-1:0]           rd_cache_data  [NO_OF_MASTERS];
  logic                            rd_data_valid  [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             rd_data_id     [NO_OF_MASTERS];
  logic                            rd_data_last   [NO_OF_MASTERS];
  logic [1:0]                      rd_resp        [NO_OF_MASTERS];
  
  // --- Write Path to Cache Interface ---
  logic                            cache_addr_valid [NO_OF_MASTERS];
  logic [ADDR_WIDTH-1:0]           cache_addr       [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             cache_id         [NO_OF_MASTERS];
  logic [7:0]                      cache_len        [NO_OF_MASTERS];
  logic [2:0]                      cache_size       [NO_OF_MASTERS];
  logic [1:0]                      cache_burst      [NO_OF_MASTERS];
  
  logic                            cache_data_valid [NO_OF_MASTERS];
  logic [DATA_WIDTH-1:0]           cache_data       [NO_OF_MASTERS];
  logic [(DATA_WIDTH/8)-1:0]       cache_strb       [NO_OF_MASTERS];
  logic                            cache_data_last  [NO_OF_MASTERS];
  
  logic                            cache_hit        [NO_OF_MASTERS];
  logic                            cache_miss       [NO_OF_MASTERS];
  logic                            cache_complete   [NO_OF_MASTERS];
  logic                            cache_resp_valid [NO_OF_MASTERS];
  logic [1:0]                      cache_resp       [NO_OF_MASTERS];
  logic [ID_WIDTH-1:0]             cache_resp_id    [NO_OF_MASTERS];

  //==========================================================================
  // MODULE INSTANTIATIONS
  //==========================================================================
  
  // -------------------------------------------------------------------------
  // READ PATH MODULE 
  // -------------------------------------------------------------------------
  axi_read_path #(
    .NO_OF_MASTERS  (NO_OF_MASTERS),
    .ADDR_WIDTH     (ADDR_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .ID_WIDTH       (ID_WIDTH),
    .MAX_OUTSTANDING(MAX_OUTSTANDING)
  ) u_read_path (
    .aclk           (aclk),
    .aresetn        (aresetn),
    
    // Master interfaces (AR + R channels)
    .m_arvalid      (m_arvalid),
    .m_arready      (m_arready),
    .m_araddr       (m_araddr),
    .m_arid         (m_arid),
    .m_arlen        (m_arlen),
    .m_arsize       (m_arsize),
    .m_arburst      (m_arburst),
    
    .m_rvalid       (m_rvalid),
    .m_rready       (m_rready),
    .m_rdata        (m_rdata),
    .m_rid          (m_rid),
    .m_rresp        (m_rresp),
    .m_rlast        (m_rlast),
    
    // Interface to Cache
    .rd_req_valid   (rd_req_valid),
    .rd_req_addr    (rd_req_addr),
    .rd_req_id      (rd_req_id),
    .rd_req_len     (rd_req_len),
    .rd_req_size    (rd_req_size),
    .rd_req_burst   (rd_req_burst),
    .rd_data_id     (rd_data_id),
    .rd_resp        (rd_resp),
    
    .rd_cache_hit   (rd_cache_hit),
    .rd_cache_miss  (rd_cache_miss),
    .rd_cache_data  (rd_cache_data),
    .rd_data_valid  (rd_data_valid),
    .rd_data_last   (rd_data_last)
  );
  
  // -------------------------------------------------------------------------
  // WRITE PATH MODULE 
  // -------------------------------------------------------------------------
  axi_write_path #(
    .NO_OF_MASTERS  (NO_OF_MASTERS),
    .ADDR_WIDTH     (ADDR_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .ID_WIDTH       (ID_WIDTH),
    .MAX_OUTSTANDING(MAX_OUTSTANDING)
  ) u_write_path (
    .aclk           (aclk),
    .aresetn        (aresetn),
    
    // Master interfaces (AW + W + B channels)
    .m_awvalid      (m_awvalid),
    .m_awready      (m_awready),
    .m_awaddr       (m_awaddr),
    .m_awid         (m_awid),
    .m_awlen        (m_awlen),
    .m_awsize       (m_awsize),
    .m_awburst      (m_awburst),
    
    .m_wvalid       (m_wvalid),
    .m_wready       (m_wready),
    .m_wdata        (m_wdata),
    .m_wstrb        (m_wstrb),
    .m_wlast        (m_wlast),
    
    .m_bvalid       (m_bvalid),
    .m_bready       (m_bready),
    .m_bid          (m_bid),
    .m_bresp        (m_bresp),
    
    // Interface to Cache 
    .cache_addr_valid (cache_addr_valid),
    .cache_addr       (cache_addr),
    .cache_id         (cache_id),
    .cache_len        (cache_len),
    .cache_size       (cache_size),
    .cache_burst      (cache_burst),
    
    .cache_data_valid (cache_data_valid),
    .cache_data       (cache_data),
    .cache_strb       (cache_strb),
    .cache_data_last  (cache_data_last),
    
    .cache_hit        (cache_hit),
    .cache_miss       (cache_miss),
    .cache_complete   (cache_complete),
    .cache_resp_valid (cache_resp_valid),
    .cache_resp       (cache_resp),
    .cache_resp_id    (cache_resp_id)
  );
  
  // -------------------------------------------------------------------------
  // CACHE CONTROLLER MODULE 
  // -------------------------------------------------------------------------
  axi_cache_controller #(
      .NO_OF_MASTERS   (NO_OF_MASTERS),
      .NO_OF_SLAVES    (NO_OF_SLAVES),
      .ADDR_WIDTH      (ADDR_WIDTH),
      .DATA_WIDTH      (DATA_WIDTH),
      .ID_WIDTH        (ID_WIDTH),
      .CACHE_LINE_SIZE (CACHE_LINE_SIZE),
      .NUM_SETS        (NUM_SETS),
      .ASSOCIATIVITY   (ASSOCIATIVITY),
      .NUM_MSHR        (NUM_MSHR)
  ) u_cache_controller (
      .aclk            (aclk),
      .aresetn         (aresetn),

      // ---------------- Read Interface ----------------
      .rd_req_valid    (rd_req_valid),
      .rd_req_addr     (rd_req_addr),
      .rd_req_id       (rd_req_id),
      .rd_req_len      (rd_req_len),
      .rd_req_size     (rd_req_size),
      .rd_req_burst    (rd_req_burst),

      .rd_ready        (rd_ready),
      .rd_cache_hit    (rd_cache_hit),
      .rd_cache_miss   (rd_cache_miss),
      .rd_cache_data   (rd_cache_data),
      .rd_data_valid   (rd_data_valid),
      .rd_data_id      (rd_data_id),
      .rd_data_last    (rd_data_last),
      .rd_resp         (rd_resp),

      // ---------------- Write Interface ----------------
      .wr_req_valid    (cache_addr_valid),
      .wr_req_addr     (cache_addr),
      .wr_req_id       (cache_id),
      .wr_req_len      (cache_len),
      .wr_req_size     (cache_size),
      .wr_req_burst    (cache_burst),

      .wr_data_valid   (cache_data_valid),
      .wr_data         (cache_data),
      .wr_strb         (cache_strb),
      .wr_data_last    (cache_data_last),

      .wr_req_ready    (),  // Not used
      .wr_cache_hit    (cache_hit),
      .wr_cache_miss   (cache_miss),
      .wr_complete     (cache_complete),
      .wr_resp_valid   (cache_resp_valid),
      .wr_resp         (cache_resp),

      // ---------------- AXI Slave Interface ----------------
      .s_arvalid       (s_arvalid),
      .s_arready       (s_arready),
      .s_araddr        (s_araddr),
      .s_arid          (s_arid),
      .s_arlen         (s_arlen),
      .s_arsize        (s_arsize),
      .s_arburst       (s_arburst),

      .s_rvalid        (s_rvalid),
      .s_rready        (s_rready),
      .s_rdata         (s_rdata),
      .s_rid           (s_rid),
      .s_rresp         (s_rresp),
      .s_rlast         (s_rlast),

      .s_awvalid       (s_awvalid),
      .s_awready       (s_awready),
      .s_awaddr        (s_awaddr),
      .s_awid          (s_awid),
      .s_awlen         (s_awlen),
      .s_awsize        (s_awsize),
      .s_awburst       (s_awburst),

      .s_wvalid        (s_wvalid),
      .s_wready        (s_wready),
      .s_wdata         (s_wdata),
      .s_wstrb         (s_wstrb),
      .s_wlast         (s_wlast),

      .s_bvalid        (s_bvalid),
      .s_bready        (s_bready),
      .s_bresp         (s_bresp)
  );

  //==========================================================================
  // CONNECT INTERNAL SIGNALS TO INTERFACE PORTS
  //==========================================================================
  
  genvar m, s;
  
  // Connect master interfaces
  generate
    for (m = 0; m < NO_OF_MASTERS; m++) begin : G_MASTER_CONNECT
      // Read address channel
      assign m_arvalid[m] = master_if[m].arvalid;
      assign master_if[m].arready = m_arready[m];
      assign m_araddr[m] = master_if[m].araddr;
      assign m_arid[m] = master_if[m].arid;
      assign m_arlen[m] = master_if[m].arlen;
      assign m_arsize[m] = master_if[m].arsize;
      assign m_arburst[m] = master_if[m].arburst;
      
      // Read data channel
      assign master_if[m].rvalid = m_rvalid[m];
      assign m_rready[m] = master_if[m].rready;
      assign master_if[m].rdata = m_rdata[m];
      assign master_if[m].rid = m_rid[m];
      assign master_if[m].rresp = m_rresp[m];
      assign master_if[m].rlast = m_rlast[m];
      
      // Write address channel
      assign m_awvalid[m] = master_if[m].awvalid;
      assign master_if[m].awready = m_awready[m];
      assign m_awaddr[m] = master_if[m].awaddr;
      assign m_awid[m] = master_if[m].awid;
      assign m_awlen[m] = master_if[m].awlen;
      assign m_awsize[m] = master_if[m].awsize;
      assign m_awburst[m] = master_if[m].awburst;
      
      // Write data channel
      assign m_wvalid[m] = master_if[m].wvalid;
      assign master_if[m].wready = m_wready[m];
      assign m_wdata[m] = master_if[m].wdata;
      assign m_wstrb[m] = master_if[m].wstrb;
      assign m_wlast[m] = master_if[m].wlast;
      
      // Write response channel
      assign master_if[m].bvalid = m_bvalid[m];
      assign m_bready[m] = master_if[m].bready;
      assign master_if[m].bid = m_bid[m];
      assign master_if[m].bresp = m_bresp[m];
    end
  endgenerate
  
  // Connect slave interfaces
  generate
    for (s = 0; s < NO_OF_SLAVES; s++) begin : G_SLAVE_CONNECT
      // Read address channel
      assign slave_if[s].arvalid = s_arvalid[s];
      assign s_arready[s] = slave_if[s].arready;
      assign slave_if[s].araddr = s_araddr[s];
      assign slave_if[s].arid = s_arid[s];
      assign slave_if[s].arlen = s_arlen[s];
      assign slave_if[s].arsize = s_arsize[s];
      assign slave_if[s].arburst = s_arburst[s];
      
      // Read data channel
      assign s_rvalid[s] = slave_if[s].rvalid;
      assign slave_if[s].rready = s_rready[s];
      assign s_rdata[s] = slave_if[s].rdata;
      assign s_rid[s] = slave_if[s].rid;
      assign s_rresp[s] = slave_if[s].rresp;
      assign s_rlast[s] = slave_if[s].rlast;
      
      // Write address channel
      assign slave_if[s].awvalid = s_awvalid[s];
      assign s_awready[s] = slave_if[s].awready;
      assign slave_if[s].awaddr = s_awaddr[s];
      assign slave_if[s].awid = s_awid[s];
      assign slave_if[s].awlen = s_awlen[s];
      assign slave_if[s].awsize = s_awsize[s];
      assign slave_if[s].awburst = s_awburst[s];
      
      // Write data channel
      assign slave_if[s].wvalid = s_wvalid[s];
      assign s_wready[s] = slave_if[s].wready;
      assign slave_if[s].wdata = s_wdata[s];
      assign slave_if[s].wstrb = s_wstrb[s];
      assign slave_if[s].wlast = s_wlast[s];
      
      // Write response channel
      assign s_bvalid[s] = slave_if[s].bvalid;
      assign slave_if[s].bready = s_bready[s];
      assign s_bid[s] = slave_if[s].bid;
      assign s_bresp[s] = slave_if[s].bresp;
    end
  endgenerate

endmodule
