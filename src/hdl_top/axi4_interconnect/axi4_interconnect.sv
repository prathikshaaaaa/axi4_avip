
`include "axi4_decoder.sv"
`include "axi4_cache_controller.sv"

module axi_interconnect_cache #(
    parameter int NO_OF_MASTERS  = 4,
    parameter int NO_OF_SLAVES   = 2,
    parameter int ADDRESS_WIDTH  = 32,
    parameter int DATA_WIDTH     = 64,
    parameter int ID_WIDTH       = 4,
    parameter int SLAVE_MEM_SIZE = 12       // FIX 1: was missing, interconnect needs it
)(
    input  logic aclk,
    input  logic aresetn,

    // INTERFACES FROM HDL TOP
    axi4_if master_if [NO_OF_MASTERS],
    axi4_if slave_if  [NO_OF_SLAVES]
);

    localparam int MASTER_BITS  = $clog2(NO_OF_MASTERS);
    localparam int EXT_ID_WIDTH = ID_WIDTH + MASTER_BITS;

    // =========================================================
    // MASTER SIDE FLATTENING
    // =========================================================
    logic [NO_OF_MASTERS-1:0] m_awvalid, m_wvalid, m_arvalid, m_bready, m_rready;
    logic [ID_WIDTH-1:0]      m_awid   [NO_OF_MASTERS], m_arid [NO_OF_MASTERS];
    logic [ADDRESS_WIDTH-1:0] m_awaddr [NO_OF_MASTERS], m_araddr [NO_OF_MASTERS];
    logic [7:0]               m_awlen  [NO_OF_MASTERS], m_arlen [NO_OF_MASTERS];
    logic [2:0]               m_awsize [NO_OF_MASTERS], m_arsize [NO_OF_MASTERS];
    logic [1:0]               m_awburst[NO_OF_MASTERS], m_arburst [NO_OF_MASTERS];
    logic [3:0]               m_awcache[NO_OF_MASTERS], m_arcache [NO_OF_MASTERS];
    logic [3:0]               m_awqos  [NO_OF_MASTERS], m_arqos [NO_OF_MASTERS];

    logic [DATA_WIDTH-1:0]      m_wdata [NO_OF_MASTERS];
    logic [(DATA_WIDTH/8)-1:0]  m_wstrb [NO_OF_MASTERS];
    logic [NO_OF_MASTERS-1:0]   m_wlast;

    logic [NO_OF_MASTERS-1:0] m_awready, m_wready, m_arready;
    logic [NO_OF_MASTERS-1:0] m_bvalid, m_rvalid, m_rlast;
    logic [ID_WIDTH-1:0]      m_bid  [NO_OF_MASTERS], m_rid [NO_OF_MASTERS];
    logic [1:0]               m_bresp[NO_OF_MASTERS], m_rresp [NO_OF_MASTERS];
    logic [DATA_WIDTH-1:0]    m_rdata[NO_OF_MASTERS];

    // CONNECT INTERFACE <-> SIGNALS
    generate
      for (genvar i = 0; i < NO_OF_MASTERS; i++) begin : GEN_M_FLAT
        assign m_awvalid[i] = master_if[i].awvalid;
        assign m_awid[i]    = master_if[i].awid;
        assign m_awaddr[i]  = master_if[i].awaddr;
        assign m_awlen[i]   = master_if[i].awlen;
        assign m_awsize[i]  = master_if[i].awsize;
        assign m_awburst[i] = master_if[i].awburst;
        assign m_awcache[i] = master_if[i].awcache;
        assign m_awqos[i]   = master_if[i].awqos;

        assign m_wvalid[i]  = master_if[i].wvalid;
        assign m_wdata[i]   = master_if[i].wdata;
        assign m_wstrb[i]   = master_if[i].wstrb;
        assign m_wlast[i]   = master_if[i].wlast;

        assign m_bready[i]  = master_if[i].bready;

        assign m_arvalid[i] = master_if[i].arvalid;
        assign m_arid[i]    = master_if[i].arid;
        assign m_araddr[i]  = master_if[i].araddr;
        assign m_arlen[i]   = master_if[i].arlen;
        assign m_arsize[i]  = master_if[i].arsize;
        assign m_arburst[i] = master_if[i].arburst;
        assign m_arcache[i] = master_if[i].arcache;
        assign m_arqos[i]   = master_if[i].arqos;

        assign m_rready[i]  = master_if[i].rready;

        assign master_if[i].awready = m_awready[i];
        assign master_if[i].wready  = m_wready[i];
        assign master_if[i].bvalid  = m_bvalid[i];
        assign master_if[i].bid     = m_bid[i];
        assign master_if[i].bresp   = m_bresp[i];
        assign master_if[i].arready = m_arready[i];
        assign master_if[i].rvalid  = m_rvalid[i];
        assign master_if[i].rid     = m_rid[i];
        assign master_if[i].rdata   = m_rdata[i];
        assign master_if[i].rresp   = m_rresp[i];
        assign master_if[i].rlast   = m_rlast[i];
      end
    endgenerate

    // =========================================================
    // FIX 2: Declare ALL interconnect->cache intermediate signals
    // (previously missing: awlen/size/burst/cache, wstrb/wlast,
    //  arlen/arsize/arburst/arcache)
    // =========================================================
    logic [NO_OF_SLAVES-1:0]      cache_awvalid, cache_wvalid, cache_arvalid;
    logic [NO_OF_SLAVES-1:0]      cache_awready, cache_wready, cache_arready;
    logic [NO_OF_SLAVES-1:0]      cache_bvalid,  cache_rvalid;
    logic [NO_OF_SLAVES-1:0]      cache_bready,  cache_rready;
    logic [NO_OF_SLAVES-1:0]      cache_wlast,   cache_rlast;

    logic [EXT_ID_WIDTH-1:0]      cache_awid    [NO_OF_SLAVES];
    logic [ADDRESS_WIDTH-1:0]     cache_awaddr  [NO_OF_SLAVES];
    logic [7:0]                   cache_awlen   [NO_OF_SLAVES];
    logic [2:0]                   cache_awsize  [NO_OF_SLAVES];
    logic [1:0]                   cache_awburst [NO_OF_SLAVES];
    logic [3:0]                   cache_awcache [NO_OF_SLAVES];

    logic [DATA_WIDTH-1:0]        cache_wdata   [NO_OF_SLAVES];
    logic [(DATA_WIDTH/8)-1:0]    cache_wstrb   [NO_OF_SLAVES];

    logic [EXT_ID_WIDTH-1:0]      cache_arid    [NO_OF_SLAVES];
    logic [ADDRESS_WIDTH-1:0]     cache_araddr  [NO_OF_SLAVES];
    logic [7:0]                   cache_arlen   [NO_OF_SLAVES];
    logic [2:0]                   cache_arsize  [NO_OF_SLAVES];
    logic [1:0]                   cache_arburst [NO_OF_SLAVES];
    logic [3:0]                   cache_arcache [NO_OF_SLAVES];

    logic [EXT_ID_WIDTH-1:0]      cache_bid     [NO_OF_SLAVES];
    logic [EXT_ID_WIDTH-1:0]      cache_rid     [NO_OF_SLAVES];
    logic [1:0]                   cache_bresp   [NO_OF_SLAVES];
    logic [DATA_WIDTH-1:0]        cache_rdata   [NO_OF_SLAVES];
    logic [EXT_ID_WIDTH-1:0]      cache_rrid    [NO_OF_SLAVES]; // rid from cache to IC
    logic [1:0]                   cache_rresp   [NO_OF_SLAVES];

    // =========================================================
    // FIX 3: Declare cache->slave (s_*) signals
    // (were completely absent from the original top)
    // =========================================================
    logic [NO_OF_SLAVES-1:0]      s_awvalid, s_wvalid,  s_arvalid;
    logic [NO_OF_SLAVES-1:0]      s_awready, s_wready,  s_arready;
    logic [NO_OF_SLAVES-1:0]      s_bvalid,  s_rvalid;
    logic [NO_OF_SLAVES-1:0]      s_bready,  s_rready;
    logic [NO_OF_SLAVES-1:0]      s_wlast,   s_rlast;

    logic [EXT_ID_WIDTH-1:0]      s_awid    [NO_OF_SLAVES];
    logic [ADDRESS_WIDTH-1:0]     s_awaddr  [NO_OF_SLAVES];
    logic [7:0]                   s_awlen   [NO_OF_SLAVES];
    logic [2:0]                   s_awsize  [NO_OF_SLAVES];
    logic [1:0]                   s_awburst [NO_OF_SLAVES];
    logic [3:0]                   s_awcache [NO_OF_SLAVES];

    logic [DATA_WIDTH-1:0]        s_wdata   [NO_OF_SLAVES];
    logic [(DATA_WIDTH/8)-1:0]    s_wstrb   [NO_OF_SLAVES];

    logic [EXT_ID_WIDTH-1:0]      s_arid    [NO_OF_SLAVES];
    logic [ADDRESS_WIDTH-1:0]     s_araddr  [NO_OF_SLAVES];
    logic [7:0]                   s_arlen   [NO_OF_SLAVES];
    logic [2:0]                   s_arsize  [NO_OF_SLAVES];
    logic [1:0]                   s_arburst [NO_OF_SLAVES];
    logic [3:0]                   s_arcache [NO_OF_SLAVES];

    logic [EXT_ID_WIDTH-1:0]      s_bid     [NO_OF_SLAVES];
    logic [1:0]                   s_bresp   [NO_OF_SLAVES];
    logic [EXT_ID_WIDTH-1:0]      s_rid     [NO_OF_SLAVES];
    logic [DATA_WIDTH-1:0]        s_rdata   [NO_OF_SLAVES];
    logic [1:0]                   s_rresp   [NO_OF_SLAVES];

    // =========================================================
    // FIX 4: INTERCONNECT — explicit port map
    // (fixes ADDR_WIDTH vs ADDRESS_WIDTH rename, passes
    //  SLAVE_MEM_SIZE, and avoids .* silently leaving ports open)
    // =========================================================
    axi4_decoder #(
        .ID_WIDTH      (ID_WIDTH),
        .ADDR_WIDTH    (ADDRESS_WIDTH),   // FIX: submodule uses ADDR_WIDTH
        .DATA_WIDTH    (DATA_WIDTH),
        .NO_OF_MASTERS (NO_OF_MASTERS),
        .NO_OF_SLAVES  (NO_OF_SLAVES),
        .SLAVE_MEM_SIZE(SLAVE_MEM_SIZE)
    ) u_ic (
        .aclk           (aclk),
        .aresetn        (aresetn),

        // Master AW
        .m_awvalid      (m_awvalid),
        .m_awid         (m_awid),
        .m_awaddr       (m_awaddr),
        .m_awlen        (m_awlen),
        .m_awsize       (m_awsize),
        .m_awburst      (m_awburst),
        .m_awcache      (m_awcache),
        .m_awqos        (m_awqos),
        .m_awready      (m_awready),

        // Master W
        .m_wvalid       (m_wvalid),
        .m_wdata        (m_wdata),
        .m_wstrb        (m_wstrb),
        .m_wlast        (m_wlast),
        .m_wready       (m_wready),

        // Master B
        .m_bvalid       (m_bvalid),
        .m_bid          (m_bid),
        .m_bresp        (m_bresp),
        .m_bready       (m_bready),

        // Master AR
        .m_arvalid      (m_arvalid),
        .m_arid         (m_arid),
        .m_araddr       (m_araddr),
        .m_arlen        (m_arlen),
        .m_arsize       (m_arsize),
        .m_arburst      (m_arburst),
        .m_arcache      (m_arcache),
        .m_arqos        (m_arqos),
        .m_arready      (m_arready),

        // Master R
        .m_rvalid       (m_rvalid),
        .m_rid          (m_rid),
        .m_rdata        (m_rdata),
        .m_rresp        (m_rresp),
        .m_rlast        (m_rlast),
        .m_rready       (m_rready),

        // Cache AW (interconnect -> cache)
        .cache_awvalid  (cache_awvalid),
        .cache_awid     (cache_awid),
        .cache_awaddr   (cache_awaddr),
        .cache_awlen    (cache_awlen),
        .cache_awsize   (cache_awsize),
        .cache_awburst  (cache_awburst),
        .cache_awcache  (cache_awcache),
        .cache_awready  (cache_awready),

        // Cache W (interconnect -> cache)
        .cache_wvalid   (cache_wvalid),
        .cache_wdata    (cache_wdata),
        .cache_wstrb    (cache_wstrb),
        .cache_wlast    (cache_wlast),
        .cache_wready   (cache_wready),

        // Cache B (cache -> interconnect)
        .cache_bvalid   (cache_bvalid),
        .cache_bid      (cache_bid),
        .cache_bresp    (cache_bresp),
        .cache_bready   (cache_bready),

        // Cache AR (interconnect -> cache)
        .cache_arvalid  (cache_arvalid),
        .cache_arid     (cache_arid),
        .cache_araddr   (cache_araddr),
        .cache_arlen    (cache_arlen),
        .cache_arsize   (cache_arsize),
        .cache_arburst  (cache_arburst),
        .cache_arcache  (cache_arcache),
        .cache_arready  (cache_arready),

        // Cache R (cache -> interconnect)
        .cache_rvalid   (cache_rvalid),
        .cache_rid      (cache_rrid),
        .cache_rdata    (cache_rdata),
        .cache_rresp    (cache_rresp),
        .cache_rlast    (cache_rlast),
        .cache_rready   (cache_rready)
    );

    // =========================================================
    // FIX 5: CACHE CONTROLLER — explicit port map
    // (wires both the interconnect-side cache_* ports AND the
    //  slave-side s_* ports; fixes MASTER_BITS being a parameter
    //  by computing it correctly from NO_OF_MASTERS)
    // =========================================================
    axi_cache_controller #(
        .NO_OF_SLAVES  (NO_OF_SLAVES),
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .ID_WIDTH      (ID_WIDTH),
        .MASTER_BITS   (MASTER_BITS),       // FIX: drive from localparam, not default
        .EXT_ID_WIDTH  (EXT_ID_WIDTH),
        .SLAVE_MEM_SIZE(SLAVE_MEM_SIZE)
    ) u_cache (
        .aclk           (aclk),
        .aresetn        (aresetn),

        // --- Interconnect-facing (upstream) ports ---
        // AW from interconnect
        .cache_awvalid  (cache_awvalid),
        .cache_awready  (cache_awready),
        .cache_awid     (cache_awid),
        .cache_awaddr   (cache_awaddr),
        .cache_awlen    (cache_awlen),
        .cache_awsize   (cache_awsize),
        .cache_awburst  (cache_awburst),
        .cache_awcache  (cache_awcache),

        // W from interconnect
        .cache_wvalid   (cache_wvalid),
        .cache_wready   (cache_wready),
        .cache_wdata    (cache_wdata),
        .cache_wstrb    (cache_wstrb),
        .cache_wlast    (cache_wlast),

        // B to interconnect
        .cache_bvalid   (cache_bvalid),
        .cache_bready   (cache_bready),
        .cache_bid      (cache_bid),
        .cache_bresp    (cache_bresp),

        // AR from interconnect
        .cache_arvalid  (cache_arvalid),
        .cache_arready  (cache_arready),
        .cache_arid     (cache_arid),
        .cache_araddr   (cache_araddr),
        .cache_arlen    (cache_arlen),
        .cache_arsize   (cache_arsize),
        .cache_arburst  (cache_arburst),
        .cache_arcache  (cache_arcache),

        // R to interconnect
        .cache_rvalid   (cache_rvalid),
        .cache_rready   (cache_rready),
        .cache_rdata    (cache_rdata),
        .cache_rid      (cache_rrid),
        .cache_rresp    (cache_rresp),
        .cache_rlast    (cache_rlast),

        // --- Slave-facing (downstream) ports ---
        // AW to slave
        .s_awvalid      (s_awvalid),
        .s_awready      (s_awready),
        .s_awaddr       (s_awaddr),
        .s_awid         (s_awid),
        .s_awlen        (s_awlen),
        .s_awsize       (s_awsize),
        .s_awburst      (s_awburst),
        .s_awcache      (s_awcache),

        // W to slave
        .s_wvalid       (s_wvalid),
        .s_wready       (s_wready),
        .s_wdata        (s_wdata),
        .s_wstrb        (s_wstrb),
        .s_wlast        (s_wlast),

        // B from slave
        .s_bvalid       (s_bvalid),
        .s_bready       (s_bready),
        .s_bresp        (s_bresp),
        .s_bid          (s_bid),

        // AR to slave
        .s_arvalid      (s_arvalid),
        .s_arready      (s_arready),
        .s_araddr       (s_araddr),
        .s_arid         (s_arid),
        .s_arlen        (s_arlen),
        .s_arsize       (s_arsize),
        .s_arburst      (s_arburst),
        .s_arcache      (s_arcache),

        // R from slave
        .s_rvalid       (s_rvalid),
        .s_rready       (s_rready),
        .s_rdata        (s_rdata),
        .s_rid          (s_rid),
        .s_rresp        (s_rresp),
        .s_rlast        (s_rlast)
    );

    // =========================================================
    // FIX 6: SLAVE INTERFACE CONNECTION — full data/address/ID
    // wiring of s_* signals to slave_if[]
    // (original only connected valid/ready handshake signals)
    // =========================================================
    generate
      for (genvar s = 0; s < NO_OF_SLAVES; s++) begin : GEN_S_FLAT

        // AW channel (cache -> slave)
        assign slave_if[s].awvalid = s_awvalid[s];
        assign s_awready[s]        = slave_if[s].awready;
        assign slave_if[s].awid    = s_awid[s];
        assign slave_if[s].awaddr  = s_awaddr[s];
        assign slave_if[s].awlen   = s_awlen[s];
        assign slave_if[s].awsize  = s_awsize[s];
        assign slave_if[s].awburst = s_awburst[s];
        assign slave_if[s].awcache = s_awcache[s];

        // W channel (cache -> slave)
        assign slave_if[s].wvalid  = s_wvalid[s];
        assign s_wready[s]         = slave_if[s].wready;
        assign slave_if[s].wdata   = s_wdata[s];
        assign slave_if[s].wstrb   = s_wstrb[s];
        assign slave_if[s].wlast   = s_wlast[s];

        // B channel (slave -> cache)
        assign s_bvalid[s]         = slave_if[s].bvalid;
        assign slave_if[s].bready  = s_bready[s];
        assign s_bid[s]            = slave_if[s].bid;
        assign s_bresp[s]          = slave_if[s].bresp;

        // AR channel (cache -> slave)
        assign slave_if[s].arvalid = s_arvalid[s];
        assign s_arready[s]        = slave_if[s].arready;
        assign slave_if[s].arid    = s_arid[s];
        assign slave_if[s].araddr  = s_araddr[s];
        assign slave_if[s].arlen   = s_arlen[s];
        assign slave_if[s].arsize  = s_arsize[s];
        assign slave_if[s].arburst = s_arburst[s];
        assign slave_if[s].arcache = s_arcache[s];

        // R channel (slave -> cache)
        assign s_rvalid[s]         = slave_if[s].rvalid;
        assign slave_if[s].rready  = s_rready[s];
        assign s_rid[s]            = slave_if[s].rid;
        assign s_rdata[s]          = slave_if[s].rdata;
        assign s_rresp[s]          = slave_if[s].rresp;
        assign s_rlast[s]          = slave_if[s].rlast;

      end
    endgenerate

endmodule
