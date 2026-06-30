module axi4_decoder #(
    parameter  int ID_WIDTH       = 4,
    parameter  int ADDR_WIDTH     = 32,
    parameter  int DATA_WIDTH     = 64,
    parameter  int NO_OF_MASTERS  = 4,
    parameter  int NO_OF_SLAVES   = 2,
    parameter  int SLAVE_MEM_SIZE = 12,
    localparam int MASTER_BITS    = $clog2(NO_OF_MASTERS),
    localparam int EXT_ID_WIDTH   = ID_WIDTH + MASTER_BITS
)(
    input  logic aclk,
    input  logic aresetn,
 
    input  logic [NO_OF_MASTERS-1:0]      m_awvalid,
    input  logic [ID_WIDTH-1:0]           m_awid    [NO_OF_MASTERS],
    input  logic [ADDR_WIDTH-1:0]         m_awaddr  [NO_OF_MASTERS],
    input  logic [7:0]                    m_awlen   [NO_OF_MASTERS],
    input  logic [2:0]                    m_awsize  [NO_OF_MASTERS],
    input  logic [1:0]                    m_awburst [NO_OF_MASTERS],
    input  logic [3:0]                    m_awcache [NO_OF_MASTERS],
    input  logic [3:0]                    m_awqos   [NO_OF_MASTERS],
 
    input  logic [NO_OF_MASTERS-1:0]      m_wvalid,
    input  logic [DATA_WIDTH-1:0]         m_wdata   [NO_OF_MASTERS],
    input  logic [(DATA_WIDTH/8)-1:0]     m_wstrb   [NO_OF_MASTERS],
    input  logic [NO_OF_MASTERS-1:0]      m_wlast,
 
    input  logic [NO_OF_MASTERS-1:0]      m_bready,
 
    input  logic [NO_OF_MASTERS-1:0]      m_arvalid,
    input  logic [ID_WIDTH-1:0]           m_arid    [NO_OF_MASTERS],
    input  logic [ADDR_WIDTH-1:0]         m_araddr  [NO_OF_MASTERS],
    input  logic [7:0]                    m_arlen   [NO_OF_MASTERS],
    input  logic [2:0]                    m_arsize  [NO_OF_MASTERS],
    input  logic [1:0]                    m_arburst [NO_OF_MASTERS],
    input  logic [3:0]                    m_arcache [NO_OF_MASTERS],
    input  logic [3:0]                    m_arqos   [NO_OF_MASTERS],
 
    input  logic [NO_OF_MASTERS-1:0]      m_rready,
 
    output logic [NO_OF_MASTERS-1:0]      m_bvalid,
    output logic [ID_WIDTH-1:0]           m_bid     [NO_OF_MASTERS],
    output logic [1:0]                    m_bresp   [NO_OF_MASTERS],
 
    output logic [NO_OF_MASTERS-1:0]      m_rvalid,
    output logic [ID_WIDTH-1:0]           m_rid     [NO_OF_MASTERS],
    output logic [DATA_WIDTH-1:0]         m_rdata   [NO_OF_MASTERS],
    output logic [1:0]                    m_rresp   [NO_OF_MASTERS],
    output logic [NO_OF_MASTERS-1:0]      m_rlast,
 
    output logic [NO_OF_MASTERS-1:0]      m_arready,
    output logic [NO_OF_MASTERS-1:0]      m_awready,
    output logic [NO_OF_MASTERS-1:0]      m_wready,
 
    output logic [NO_OF_SLAVES-1:0]       cache_awvalid,
    output logic [EXT_ID_WIDTH-1:0]       cache_awid    [NO_OF_SLAVES],
    output logic [ADDR_WIDTH-1:0]         cache_awaddr  [NO_OF_SLAVES],
    output logic [7:0]                    cache_awlen   [NO_OF_SLAVES],
    output logic [2:0]                    cache_awsize  [NO_OF_SLAVES],
    output logic [1:0]                    cache_awburst [NO_OF_SLAVES],
    output logic [3:0]                    cache_awcache [NO_OF_SLAVES],
 
    output logic [NO_OF_SLAVES-1:0]       cache_wvalid,
    output logic [DATA_WIDTH-1:0]         cache_wdata   [NO_OF_SLAVES],
    output logic [(DATA_WIDTH/8)-1:0]     cache_wstrb   [NO_OF_SLAVES],
    output logic [NO_OF_SLAVES-1:0]       cache_wlast,
 
    output logic [NO_OF_SLAVES-1:0]       cache_arvalid,
    output logic [EXT_ID_WIDTH-1:0]       cache_arid    [NO_OF_SLAVES],
    output logic [ADDR_WIDTH-1:0]         cache_araddr  [NO_OF_SLAVES],
    output logic [7:0]                    cache_arlen   [NO_OF_SLAVES],
    output logic [2:0]                    cache_arsize  [NO_OF_SLAVES],
    output logic [1:0]                    cache_arburst [NO_OF_SLAVES],
    output logic [3:0]                    cache_arcache [NO_OF_SLAVES],
 
    output logic [NO_OF_SLAVES-1:0]       cache_rready,
    output logic [NO_OF_SLAVES-1:0]       cache_bready,
 
    input  logic [NO_OF_SLAVES-1:0]       cache_arready,
    input  logic [NO_OF_SLAVES-1:0]       cache_awready,
    input  logic [NO_OF_SLAVES-1:0]       cache_wready,
 
    input  logic [NO_OF_SLAVES-1:0]       cache_bvalid,
    input  logic [EXT_ID_WIDTH-1:0]       cache_bid     [NO_OF_SLAVES],
    input  logic [1:0]                    cache_bresp   [NO_OF_SLAVES],
 
    input  logic [NO_OF_SLAVES-1:0]       cache_rvalid,
    input  logic [DATA_WIDTH-1:0]         cache_rdata   [NO_OF_SLAVES],
    input  logic [EXT_ID_WIDTH-1:0]       cache_rid     [NO_OF_SLAVES],
    input  logic [1:0]                    cache_rresp   [NO_OF_SLAVES],
    input  logic [NO_OF_SLAVES-1:0]       cache_rlast
);
 
    int wr_active_master [NO_OF_SLAVES];
    int wr_prev_grant    [NO_OF_SLAVES];
    int rd_active_master [NO_OF_SLAVES];
    int rd_prev_grant    [NO_OF_SLAVES];
 
    int slave_aw_order  [NO_OF_SLAVES] [$];
    int master_aw_order [NO_OF_MASTERS][$];
 
    int wr_w_slave [NO_OF_MASTERS];
 
    typedef int slave_q_t[$];
    slave_q_t wr_respOrder [NO_OF_MASTERS][int];
    slave_q_t rd_respOrder [NO_OF_MASTERS][int];
 
    logic wr_just_released [NO_OF_SLAVES];
    logic wr_slave_busy [NO_OF_SLAVES];
    logic rd_just_released [NO_OF_SLAVES];
    logic rd_slave_busy [NO_OF_SLAVES];
 
    generate
        for (genvar s = 0; s < NO_OF_SLAVES; s++) begin : M2S
            always_comb begin
                cache_awvalid[s] = '0;
                cache_awid[s]    = '0;
                cache_awaddr[s]  = '0;
                cache_awlen[s]   = '0;
                cache_awsize[s]  = '0;
                cache_awburst[s] = '0;
                cache_awcache[s] = '0;
 
                cache_wvalid[s]  = '0;
                cache_wdata[s]   = '0;
                cache_wstrb[s]   = '0;
                cache_wlast[s]   = '0;
 
                cache_arvalid[s] = '0;
                cache_arid[s]    = '0;
                cache_araddr[s]  = '0;
                cache_arlen[s]   = '0;
                cache_arsize[s]  = '0;
                cache_arburst[s] = '0;
                cache_arcache[s] = '0;
 
                if (wr_active_master[s] != -1) begin
                    int m;
                    m = wr_active_master[s];
                    if (map_slave_addr(m_awaddr[m]) == s) begin
                        cache_awvalid[s] = m_awvalid[m];
                        cache_awid[s]    = {m[MASTER_BITS-1:0], m_awid[m]};
                        cache_awaddr[s]  = m_awaddr[m];
                        cache_awlen[s]   = m_awlen[m];
                        cache_awsize[s]  = m_awsize[m];
                        cache_awburst[s] = m_awburst[m];
                        cache_awcache[s] = m_awcache[m];
                    end
                end
 
                for (int m = 0; m < NO_OF_MASTERS; m++) begin
                    if (wr_w_slave[m] != -1 && wr_w_slave[m] == s) begin
                        cache_wvalid[s] = m_wvalid[m];
                        cache_wdata[s]  = m_wdata[m];
                        cache_wstrb[s]  = m_wstrb[m];
                        cache_wlast[s]  = m_wlast[m];
                    end
                end
 
                if (rd_active_master[s] != -1) begin
                    int m;
                    m = rd_active_master[s];
                    cache_arvalid[s] = m_arvalid[m];
                    cache_arid[s]    = {m[MASTER_BITS-1:0], m_arid[m]};
                    cache_araddr[s]  = m_araddr[m];
                    cache_arlen[s]   = m_arlen[m];
                    cache_arsize[s]  = m_arsize[m];
                    cache_arburst[s] = m_arburst[m];
                    cache_arcache[s] = m_arcache[m];
                end
            end
        end
    endgenerate
 
    always_comb begin
        logic [NO_OF_SLAVES-1:0] b_allowed;
        logic [NO_OF_SLAVES-1:0] r_allowed;
        b_allowed = '0;
        r_allowed = '0;
 
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
            m_awready[m] = '0;
            m_wready[m]  = '0;
            m_bvalid[m]  = '0;
            m_bresp[m]   = '0;
            m_bid[m]     = '0;
            m_arready[m] = '0;
            m_rvalid[m]  = '0;
            m_rdata[m]   = '0;
            m_rresp[m]   = '0;
            m_rid[m]     = '0;
            m_rlast[m]   = '0;
        end
 
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
            cache_bready[s] = '0;
            cache_rready[s] = '0;
        end
 
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
            if (wr_active_master[s] != -1) begin
                m_awready[wr_active_master[s]] = cache_awready[s];
                $display("DECODER AW/AR ready pass-through write T=%0t wr_active_master[%0d] = %0d",
                         $time, s, wr_active_master[s]);
            end
            if (rd_active_master[s] != -1) begin
                m_arready[rd_active_master[s]] = cache_arready[s];
                $display("DECODER AW/AR ready pass-through read T=%0t rd_active_master[%0d] = %0d",$time, s, rd_active_master[s]);
            end
        end
 
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
            if (wr_w_slave[m] != -1)
                m_wready[m] = cache_wready[wr_w_slave[m]];
        end
 
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
            if (cache_bvalid[s]) begin
                automatic logic [MASTER_BITS-1:0] master_index;
                automatic logic [ID_WIDTH-1:0]    axi_id;
                master_index = cache_bid[s][EXT_ID_WIDTH-1 -: MASTER_BITS];
                axi_id       = cache_bid[s][ID_WIDTH-1:0];
                $display("[DECODER_BRESP_CHECK] time=%0t s=%0d cache_bid=0x%0h master_index=%0d axi_id=0x%0h respOrder_front=%0d",$time, s, cache_bid[s], master_index, axi_id,(wr_respOrder[master_index].exists(int'(axi_id)) && wr_respOrder[master_index][int'(axi_id)].size()>0) ? wr_respOrder[master_index][int'(axi_id)][0] : -1);
 
                if (wr_respOrder[master_index].exists(int'(axi_id)) &&
                    wr_respOrder[master_index][int'(axi_id)].size() > 0 &&
                    wr_respOrder[master_index][int'(axi_id)][0] == s) begin
 
                    if (!m_bvalid[master_index]) begin
                        m_bvalid[master_index] = cache_bvalid[s];
                        m_bresp[master_index]  = cache_bresp[s];
                        m_bid[master_index]    = axi_id;
                        b_allowed[s]           = 1'b1;
                    end
                    cache_bready[s] = m_bready[master_index];
                end else begin
                    cache_bready[s] = 1'b0;
                end
            end
        end
 
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
            if (cache_rvalid[s]) begin
                automatic logic [MASTER_BITS-1:0] master_index;
                automatic logic [ID_WIDTH-1:0]    axi_id;
                master_index = cache_rid[s][EXT_ID_WIDTH-1 -: MASTER_BITS];
                axi_id       = cache_rid[s][ID_WIDTH-1:0];
 
                if (rd_respOrder[master_index].exists(int'(axi_id)) &&
                    rd_respOrder[master_index][int'(axi_id)].size() > 0 &&
                    rd_respOrder[master_index][int'(axi_id)][0] == s) begin
 
                    if (m_rvalid[master_index] == 1'b0) begin
                        m_rvalid[master_index] = cache_rvalid[s];
                        m_rdata[master_index]  = cache_rdata[s];
                        m_rresp[master_index]  = cache_rresp[s];
                        m_rlast[master_index]  = cache_rlast[s];
                        m_rid[master_index]    = axi_id;
                        r_allowed[s]           = 1'b1;
                    end
                end
            end
 
            if (r_allowed[s]) begin
                automatic logic [MASTER_BITS-1:0] m_idx =
                    cache_rid[s][EXT_ID_WIDTH-1 -: MASTER_BITS];
                cache_rready[s] = m_rready[m_idx];
            end
        end
    end
 
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                master_aw_order[m].delete();
                wr_w_slave[m] = -1;
            end
        end else begin
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                $display("%0t:in always block m_awvalid[%d] = %b | m_awaddr[%d] = %b", $time,m,m_awvalid[m],m, m_awaddr[m]);
                if (m_awvalid[m] && m_awready[m]) begin
                    int s;
                    s = map_slave_addr(m_awaddr[m]);
                    master_aw_order[m].push_back(s);
                    wr_respOrder[m][int'(m_awid[m])].push_back(s);
                    wr_w_slave[m] = master_aw_order[m][0];
                end
            end
 
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                if (m_arvalid[m] && m_arready[m]) begin
                    automatic int s = map_slave_addr(m_araddr[m]);
                    rd_respOrder[m][int'(m_arid[m])].push_back(s);
                end
            end
 
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                if (m_wvalid[m] && m_wready[m] && m_wlast[m]) begin
                    if (master_aw_order[m].size() > 0)
                        void'(master_aw_order[m].pop_front());
                    if (master_aw_order[m].size() > 0)
                        wr_w_slave[m] = master_aw_order[m][0];
                    else
                        wr_w_slave[m] = -1;
                end
            end
        end
    end
 
    always_ff @(posedge aclk or negedge aresetn) begin 
        if (!aresetn) begin
            for (int s = 0; s < NO_OF_SLAVES; s++) begin
                wr_active_master[s]  = -1;
                wr_prev_grant[s]     = -1;
                wr_just_released[s]  = 1'b0;
                wr_slave_busy[s] = 1'b0;
            end
        end else begin
            for (int s = 0; s < NO_OF_SLAVES; s++) begin
                wr_just_released[s] = 1'b0;
 
                if (wr_active_master[s] == -1 && !wr_just_released[s] && !wr_slave_busy[s]) begin
                    int next;
                    next = select_master(s, 1);
                    if (next != -1) begin
                        wr_active_master[s] = next;
                        wr_prev_grant[s]    = next;
                    end
                end
                else if (wr_active_master[s] != -1 &&
                         m_awvalid[wr_active_master[s]] &&
                         m_awready[wr_active_master[s]]) begin
                    $display("DECODER_AW_HANDSHAKE T=%0t Slave=%0d Master=%0d ID=%h",
                             $time, s, wr_active_master[s],{wr_active_master[s][MASTER_BITS-1:0],m_awid[wr_active_master[s]]});
                    wr_active_master[s] = -1;
                    wr_just_released[s] = 1'b1;
                    wr_slave_busy[s]    = 1'b1;
                end
            end
        end
    end
 
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int s = 0; s < NO_OF_SLAVES; s++) begin
                rd_active_master[s]  = -1;
                rd_prev_grant[s]     = -1;
                rd_just_released[s]  = 1'b0;
                rd_slave_busy[s]    = 1'b0;
            end
        end else begin
            for (int s = 0; s < NO_OF_SLAVES; s++) begin
                rd_just_released[s] = 1'b0;
 
                if (rd_active_master[s] == -1 && !rd_just_released[s] && !rd_slave_busy[s]) begin
                    int next;
                    next = select_master(s, 0);
                    if (next != -1) begin
                        rd_active_master[s] = next;
                        rd_prev_grant[s]    = next;
                    end
                end
                else if (rd_active_master[s] != -1 &&
                         m_arvalid[rd_active_master[s]] &&
                         m_arready[rd_active_master[s]]) begin
                     $display("DECODER_AR_HANDSHAKE T=%0t Slave=%0d Master=%0d ID=%h",$time,s,rd_active_master[s],{rd_active_master[s][MASTER_BITS-1:0],m_arid[rd_active_master[s]]});
                    rd_active_master[s] = -1;
                    rd_just_released[s] = 1'b1;
                    rd_slave_busy[s]    = 1'b1;
                end
            end
        end
    end
 
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                wr_respOrder[m].delete();
                rd_respOrder[m].delete();
            end
        end else begin
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                if (m_bvalid[m] && m_bready[m]) begin
                    automatic logic [ID_WIDTH-1:0] bid = m_bid[m];
                    if (wr_respOrder[m].exists(int'(bid)) && wr_respOrder[m][int'(bid)].size() > 0) begin
                        automatic int s;
                        s = wr_respOrder[m][int'(bid)][0];       // ← which slave this B belongs to
                        void'(wr_respOrder[m][int'(bid)].pop_front());
                        wr_slave_busy[s] = 1'b0;            // ← clear busy same cycle
                    end
                end
            end
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                if (m_rvalid[m] && m_rready[m] && m_rlast[m]) begin
                    automatic logic [ID_WIDTH-1:0] rid = m_rid[m];
                    if (rd_respOrder[m].exists(int'(rid)) &&
                        rd_respOrder[m][int'(rid)].size() > 0) begin
                        automatic int s;
                        s = rd_respOrder[m][int'(rid)][0];  // which slave this R came from
                        void'(rd_respOrder[m][int'(rid)].pop_front());
                        rd_slave_busy[s] = 1'b0;
                        $display("Releasing slave_busy for slave=%0d at time=%0t",s,$time);
                    end
                end
            end
        end
    end

    // =====================================================================
    // READ DATA — per-beat display (fires every accepted beat, not just last)
   // =====================================================================
   always_ff @(posedge aclk) begin
     for (int m = 0; m < NO_OF_MASTERS; m++) begin
        if (m_rvalid[m] && m_rready[m]) begin
            $display("[%0t] DECODER_BEAT: master=%0d rid=0x%0h rdata=0x%0h rresp=%0b rlast=%0b",$time, m, m_rid[m], m_rdata[m], m_rresp[m], m_rlast[m]);
        if (m_rlast[m])
            $display("[%0t] DECODER_R_COMPLETE: master=%0d rid=0x%0h — all beats done",$time, m, m_rid[m]);
         end
      end
    end
 
    function automatic logic [$clog2(NO_OF_SLAVES):0] map_slave_addr(
        logic [ADDR_WIDTH-1:0] addr_in
    );
        for (int i = 0; i < NO_OF_SLAVES; i++) begin
            if (addr_in >= (i * (1 << SLAVE_MEM_SIZE)) &&
                addr_in <  ((i+1) * (1 << SLAVE_MEM_SIZE)))
                return i;
        end
        return '0;
    endfunction
 
    function automatic int select_master(int targetSlave, int isWrite);
        logic localWriteReq [NO_OF_MASTERS];
        logic localReadReq  [NO_OF_MASTERS];
        int selectedMaster = -1;
        int highestQos     = -1;
        int equal_qos_cnt  =  0;
        bit firstReqSeen   =  0;
 
        if (isWrite == 1) begin
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                localWriteReq[m] = m_awvalid[m] ?
                    (map_slave_addr(m_awaddr[m]) == targetSlave) : 0;
                
                $display("localWriteReq[%0d] = %0d | m_awvalid[%b] = %b ",m,localWriteReq[m] , m, m_awvalid[m] );
                $display(" m_awaddr[%0d] = %0d ",m,m_awaddr[m]);
                $display("map_slave_addr(m_awaddr[%0d]) = %0d | targetSlave =%0d $clog2(NO_OF_SLAVES)+1)'(targetSlave) = %0d ",m,map_slave_addr(m_awaddr[m]),targetSlave,($clog2(NO_OF_SLAVES)+1)'(targetSlave)); 
                if(m_awvalid[m])
                    $display(" m_awvalid[%b] = %b ",m,m_awvalid[m]);
            end
 
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                if (localWriteReq[m]) begin
                    if (!firstReqSeen) begin
                        highestQos = int'(m_awqos[m]); selectedMaster = m; firstReqSeen = 1;
                    end else if (int'(m_awqos[m]) > highestQos) begin
                        highestQos = int'(m_awqos[m]); selectedMaster = m;
                    end
                end
            end
 
            if (!firstReqSeen) return -1;
 
            equal_qos_cnt = 0;
            for (int m = 0; m < NO_OF_MASTERS; m++)
                if (localWriteReq[m] && int'(m_awqos[m]) == highestQos) equal_qos_cnt++;
 
            if (equal_qos_cnt == 1) return selectedMaster;
 
            for (int i = 1; i <= NO_OF_MASTERS; i++) begin
                automatic int nextIdx = (wr_prev_grant[targetSlave] + i) % NO_OF_MASTERS;
                if (localWriteReq[nextIdx] && int'(m_awqos[nextIdx]) == highestQos)
                    return nextIdx;
            end
            return selectedMaster;
 
        end else begin
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                localReadReq[m] = m_arvalid[m] ?
                    (map_slave_addr(m_araddr[m]) == targetSlave) : 0;
            end
 
            firstReqSeen = 0;
            for (int m = 0; m < NO_OF_MASTERS; m++) begin
                if (localReadReq[m]) begin
                    if (!firstReqSeen) begin
                        highestQos = int'(m_arqos[m]); selectedMaster = m; firstReqSeen = 1;
                    end else if (int'(m_arqos[m]) > highestQos) begin
                        highestQos = int'(m_arqos[m]); selectedMaster = m;
                    end
                end
            end
 
            if (!firstReqSeen) return -1;
 
            equal_qos_cnt = 0;
            for (int m = 0; m < NO_OF_MASTERS; m++)
                if (localReadReq[m] && int'(m_arqos[m]) == highestQos) equal_qos_cnt++;
 
            if (equal_qos_cnt == 1) return selectedMaster;
 
            for (int i = 1; i <= NO_OF_MASTERS; i++) begin
                automatic int nextIdx = (rd_prev_grant[targetSlave] + i) % NO_OF_MASTERS;
                if (localReadReq[nextIdx] && int'(m_arqos[nextIdx]) == highestQos)
                    return nextIdx;
            end
            return selectedMaster;
        end
    endfunction
 
endmodule
