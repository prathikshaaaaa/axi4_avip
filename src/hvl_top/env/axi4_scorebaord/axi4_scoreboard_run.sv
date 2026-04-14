
task axi4_scoreboard::run_phase(uvm_phase phase);
  super.run_phase(phase);
  
//===========================================================================
// WRITE ADDRESS PATH - Master Side
//===========================================================================

foreach(axi4_master_write_address_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx  m_write_addr_tx;
      int   s_idx;
      pending_write_transaction_t pending_tx;

      axi4_master_write_address_analysis_fifo[m_idx].get(m_write_addr_tx);

      axi4_master_tx_awaddr_count[m_idx]++;
      total_master_tx_count++;

      `uvm_info("MSTR_WR_ADDR",
        $sformatf("M[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d AWCACHE=0x%0h",
          m_idx,
          m_write_addr_tx.awid,
          m_write_addr_tx.awaddr,
          m_write_addr_tx.awlen,
          m_write_addr_tx.awcache),
        UVM_MEDIUM)

      s_idx = get_slave_index(m_write_addr_tx.awaddr);

      if(s_idx == -1) begin
        `uvm_error("ADDR_DECODE",
          $sformatf("M[%0d] AWADDR=0x%0h doesn't map to any slave",
            m_idx, m_write_addr_tx.awaddr))
        continue;
      end

      l3_handle_write_request(m_idx, m_write_addr_tx, s_idx);  //decides hit or miss , allocates mshr if miss

      rr_write_pending_cnt[s_idx][m_idx]++;

      $cast(pending_tx.tx, m_write_addr_tx.clone());

      pending_tx.master_id           = m_idx;
      pending_tx.slave_id            = s_idx;
      pending_tx.address_granted     = 1;
      pending_tx.write_data_complete = 0;
      pending_tx.beats_received      = 0;

      pending_write_txns[s_idx][m_idx][m_write_addr_tx.awid].push_back(pending_tx);

      master_aw_queue[m_idx].push_back({s_idx, int'(m_write_addr_tx.awid)});

      `uvm_info("WR_PENDING",
        $sformatf("M[%0d]->S[%0d] AWID=0x%0h pushed "
                  "(pending depth=%0d aw_queue depth=%0d)",
          m_idx, s_idx,
          m_write_addr_tx.awid,
          pending_write_txns[s_idx][m_idx][m_write_addr_tx.awid].size(),
          master_aw_queue[m_idx].size()),
        UVM_HIGH)

    end // forever
  join_none
end


//===========================================================================
// WRITE ADDRESS PATH - Slave Side
//
// Slave AW = writeback evictions ONLY.
// No master write matching here.
//===========================================================================

foreach(axi4_slave_write_address_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_write_addr_tx;
      bit           found;

      axi4_slave_write_address_analysis_fifo[s_idx].get(s_write_addr_tx);
      axi4_slave_tx_awaddr_count[s_idx]++;

      `uvm_info("SLV_WR_ADDR",
        $sformatf("S[%0d] AWID=0x%0h AWADDR=0x%0h AWLEN=%0d",
          s_idx,
          s_write_addr_tx.awid,
          s_write_addr_tx.awaddr,
          s_write_addr_tx.awlen),
        UVM_MEDIUM)

      found = 0;

      for(int wb_idx = 0; wb_idx < MAX_MSHR; wb_idx++) begin

        if(scb_mshr[wb_idx].valid          &&
           scb_mshr[wb_idx].needs_writeback &&
           !scb_mshr[wb_idx].wb_done        &&
           scb_mshr[wb_idx].slave == s_idx) begin

          bit [ADDR_WIDTH-1:0] expected_wb_addr;
          expected_wb_addr = {
            l3_cache[scb_mshr[wb_idx].index][scb_mshr[wb_idx].way].tag,
            scb_mshr[wb_idx].index[L3_INDEX_BITS-1:0],
            {L3_OFFSET_BITS{1'b0}}
          };

          if(s_write_addr_tx.awaddr == expected_wb_addr) begin

            if(s_write_addr_tx.awlen != (WORDS_PER_LINE - 1)) begin
              `uvm_error("WB_AWLEN_MISMATCH",
                $sformatf("S[%0d] MSHR[%0d] WB AWLEN=%0d expected=%0d",
                  s_idx, wb_idx,
                  s_write_addr_tx.awlen,
                  WORDS_PER_LINE - 1))
            end

            `uvm_info("WB_ADDR_GRANTED",
              $sformatf("S[%0d] MSHR[%0d] AWID=0x%0h AWADDR=0x%0h "
                        "WRITEBACK GRANTED",
                s_idx, wb_idx,
                s_write_addr_tx.awid,
                s_write_addr_tx.awaddr),
              UVM_MEDIUM)

            ->slave_write_addr_granted[s_idx];

            found = 1;
            break;
          end
        end
      end

      if(!found) begin
        `uvm_error("WR_ADDR_NO_MATCH",
          $sformatf("S[%0d] AWID=0x%0h AWADDR=0x%0h: "
                    "no active writeback MSHR matches",
            s_idx,
            s_write_addr_tx.awid,
            s_write_addr_tx.awaddr))
      end

    end // forever
  join_none
end
  
  
//===========================================================================
// WRITE DATA PATH - MASTER Side
//===========================================================================

foreach(axi4_master_write_data_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx              m_write_data_tx;
      pending_write_transaction_t pending_tx;
      int                         s_idx;
      int                         awid_int;
      bit [ID_WIDTH-1:0]          awid;

      axi4_master_write_data_analysis_fifo[m_idx].get(m_write_data_tx);
      axi4_master_tx_wdata_count[m_idx]++;

      `uvm_info("MSTR_WR_DATA",
        $sformatf("M[%0d] WDATA[0]=0x%0h WSTRB=0x%0h WLAST=%0b",
          m_idx,
          m_write_data_tx.wdata[0],
          m_write_data_tx.wstrb[0],
          m_write_data_tx.wlast),
        UVM_HIGH)

      if(master_aw_queue[m_idx].size() == 0) begin
        `uvm_error("MSTR_WR_DATA_NO_AW",
          $sformatf("M[%0d] W beat received but master_aw_queue is empty. "
                    "WDATA=0x%0h WLAST=%0b",
            m_idx,
            m_write_data_tx.wdata[0],
            m_write_data_tx.wlast))
        continue;
      end

      s_idx    = master_aw_queue[m_idx][0][0]; // slave index
      awid_int = master_aw_queue[m_idx][0][1]; // local awid
      awid     = bit'(awid_int);

      if(pending_write_txns[s_idx][m_idx][awid].size() == 0) begin
        `uvm_error("MSTR_WR_DATA_NO_PENDING",
          $sformatf("M[%0d] S[%0d] AWID=0x%0h aw_queue points to "
                    "empty pending_write_txns entry",
            m_idx, s_idx, awid))
        continue;
      end

      pending_tx = pending_write_txns[s_idx][m_idx][awid][0];

      pending_tx.beats_received++;

      `uvm_info("MSTR_WR_DATA_BEAT",
        $sformatf("M[%0d] S[%0d] AWID=0x%0h beat=%0d/%0d "
                  "WDATA=0x%0h WSTRB=0x%0h",
          m_idx, s_idx, awid,
          pending_tx.beats_received,
          pending_tx.tx.awlen + 1,
          m_write_data_tx.wdata[0],
          m_write_data_tx.wstrb[0]),
        UVM_HIGH)

      if(m_write_data_tx.wlast) begin
        if(pending_tx.beats_received != (pending_tx.tx.awlen + 1)) begin
          `uvm_error("MSTR_WLAST_EARLY",
            $sformatf("M[%0d] S[%0d] AWID=0x%0h "
                      "WLAST at beat=%0d but AWLEN+1=%0d",
              m_idx, s_idx, awid,
              pending_tx.beats_received,
              pending_tx.tx.awlen + 1))
        end
      end else begin
        if(pending_tx.beats_received > pending_tx.tx.awlen) begin
          `uvm_error("MSTR_WLAST_LATE",
            $sformatf("M[%0d] S[%0d] AWID=0x%0h "
                      "beat=%0d exceeded AWLEN=%0d no WLAST",
              m_idx, s_idx, awid,
              pending_tx.beats_received,
              pending_tx.tx.awlen))
        end
      end

      l3_handle_write_data(m_idx, m_write_data_tx);
      if(m_write_data_tx.wlast) begin

        if(pending_tx.beats_received == (pending_tx.tx.awlen + 1))
          byte_data_cmp_verified_wlast_count++;

        pending_tx.write_data_complete = 1;

        `uvm_info("MSTR_WR_DATA_COMPLETE",
          $sformatf("M[%0d] S[%0d] AWID=0x%0h "
                    "write data COMPLETE beats=%0d",
            m_idx, s_idx, awid,
            pending_tx.beats_received),
          UVM_MEDIUM)

        // Pop front of AW queue — done with this transaction's data
        void'(master_aw_queue[m_idx].pop_front());
      end

      // Write updated struct back to queue
      pending_write_txns[s_idx][m_idx][awid][0] = pending_tx;

    end // forever
  join_none
end
  
    
//===========================================================================
// WRITE DATA PATH - SLAVE Side
//========================================================================


foreach(axi4_slave_write_data_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_write_data_tx;
      bit           found;
      int           wb_mshr_idx;

      @(slave_write_addr_granted[s_idx]);

      axi4_slave_write_data_analysis_fifo[s_idx].get(s_write_data_tx);
      axi4_slave_tx_wdata_count[s_idx]++;

      `uvm_info("SLV_WR_DATA",
        $sformatf("S[%0d] WDATA=0x%0h WSTRB=0x%0h WLAST=%0b",
          s_idx,
          s_write_data_tx.wdata[0],
          s_write_data_tx.wstrb[0],
          s_write_data_tx.wlast),
        UVM_HIGH)

      found       = 0;
      wb_mshr_idx = -1;

      for(int wb_idx = 0; wb_idx < MAX_MSHR; wb_idx++) begin
        if(scb_mshr[wb_idx].valid          &&
           scb_mshr[wb_idx].needs_writeback &&
           !scb_mshr[wb_idx].wb_done        &&
           scb_mshr[wb_idx].slave == s_idx) begin
          found       = 1;
          wb_mshr_idx = wb_idx;
          break;
        end
      end

      if(!found) begin
        `uvm_error("SLV_WR_DATA_NO_WB",
          $sformatf("S[%0d] WB data beat received but no active "
                    "writeback MSHR found. WDATA=0x%0h WLAST=%0b",
            s_idx,
            s_write_data_tx.wdata[0],
            s_write_data_tx.wlast))
        continue;
      end
      begin : WB_DATA_CHECK
        bit [ADDR_WIDTH-1:0] wb_base_addr;
        int                  beat_num;
        longint              beat_base;

        wb_base_addr = {
          l3_cache[scb_mshr[wb_mshr_idx].index]
                  [scb_mshr[wb_mshr_idx].way].tag,
          scb_mshr[wb_mshr_idx].index[L3_INDEX_BITS-1:0],
          {L3_OFFSET_BITS{1'b0}}
        };

        beat_num  = wb_beat_tracker[s_idx];
        beat_base = longint'(wb_base_addr) + beat_num * AXI_DATA_BYTES;

        `uvm_info("WB_DATA_BEAT",
          $sformatf("S[%0d] MSHR[%0d] beat=%0d beat_base=0x%0h",
            s_idx, wb_mshr_idx, beat_num, beat_base),
          UVM_HIGH)

        for(int lane = 0; lane < AXI_DATA_BYTES; lane++) begin
          if(s_write_data_tx.wstrb[0][lane]) begin
            longint byte_addr     = beat_base + lane;
            byte    expected_byte;
            byte    dut_byte;

            expected_byte = referenceData[s_idx].exists(byte_addr)
                            ? referenceData[s_idx][byte_addr]
                            : 8'h00;

            dut_byte = s_write_data_tx.wdata[0][8*lane +: 8];

            if(expected_byte !== dut_byte) begin
              `uvm_error("WB_DATA_MISMATCH",
                $sformatf("S[%0d] MSHR[%0d] beat=%0d "
                          "addr=0x%0h lane=%0d "
                          "Expected=0x%0h Got=0x%0h",
                  s_idx, wb_mshr_idx, beat_num,
                  byte_addr, lane,
                  expected_byte, dut_byte))
            end
          end
        end

        wb_beat_tracker[s_idx]++;

        if(s_write_data_tx.wlast) begin
          if(wb_beat_tracker[s_idx] != WORDS_PER_LINE) begin
            `uvm_error("WB_WLAST_COUNT",
              $sformatf("S[%0d] MSHR[%0d] WLAST after %0d beats "
                        "expected %0d",
                s_idx, wb_mshr_idx,
                wb_beat_tracker[s_idx],
                WORDS_PER_LINE))
          end else begin
            `uvm_info("WB_DATA_COMPLETE",
              $sformatf("S[%0d] MSHR[%0d] WB data COMPLETE "
                        "beats=%0d base=0x%0h",
                s_idx, wb_mshr_idx,
                wb_beat_tracker[s_idx],
                wb_base_addr),
              UVM_MEDIUM)
          end
          // Reset for next writeback on this slave
          wb_beat_tracker[s_idx] = 0;
          // wb_done set in BRESP path only — not here
        end

      end : WB_DATA_CHECK

    end // forever
  join_none
end

//===========================================================================
// WRITE RESPONSE PATH - Master Side
//===========================================================================

foreach(axi4_master_write_response_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx              m_write_resp_tx;
      pending_write_transaction_t pending_tx;
      int                         mshr_idx;
      int                         s_idx;

      axi4_master_write_response_analysis_fifo[m_idx].get(m_write_resp_tx);
      axi4_master_tx_bresp_count[m_idx]++;
      total_master_tx_count++;

      `uvm_info("MSTR_WR_RESP",
        $sformatf("M[%0d] BID=0x%0h BRESP=0x%0h",
                  m_idx, m_write_resp_tx.bid, m_write_resp_tx.bresp),
        UVM_MEDIUM)

      mshr_idx = -1;
      s_idx    = -1;

      begin : FIND_SLAVE
        for(int s = 0; s < NO_OF_SLAVES; s++) begin
          if(pending_write_txns[s].exists(m_write_resp_tx.bid)) begin
            if(pending_write_txns[s][m_write_resp_tx.bid].size() > 0) begin
              s_idx = s;
              break;
            end
          end
        end
      end : FIND_SLAVE

      if(s_idx == -1) begin
        `uvm_error("MSTR_BRESP_NO_SLAVE",
          $sformatf("M[%0d] BID=0x%0h cannot find pending master transaction",
                    m_idx, m_write_resp_tx.bid))
        continue;
      end

      pending_tx = pending_write_txns[s_idx][m_write_resp_tx.bid].pop_front();

      if(!pending_tx.write_data_complete) begin
        `uvm_error("BRESP_BEFORE_WLAST",
          $sformatf("M[%0d] S[%0d] BID=0x%0h BRESP received before WLAST",
                    m_idx, s_idx, m_write_resp_tx.bid))
      end

      mshr_idx = scb_find_existing_mshr(pending_tx.tx.awaddr);

      if(mshr_idx != -1          &&
         scb_mshr[mshr_idx].valid    &&
         scb_mshr[mshr_idx].is_write &&
         scb_mshr[mshr_idx].master == m_idx) begin

        if(scb_mshr[mshr_idx].needs_writeback && !scb_mshr[mshr_idx].wb_done) begin
          `uvm_error("MASTER_BRESP_BEFORE_WB_DONE",
            $sformatf("M[%0d] S[%0d] BID=0x%0h MSHR[%0d]: master BRESP before writeback BRESP completed",
                      m_idx, s_idx, m_write_resp_tx.bid, mshr_idx))
        end

        if(!scb_mshr[mshr_idx].done) begin
          `uvm_error("MASTER_BRESP_BEFORE_REFILL",
            $sformatf("M[%0d] S[%0d] BID=0x%0h MSHR[%0d]: master BRESP before refill complete",
                      m_idx, s_idx, m_write_resp_tx.bid, mshr_idx))
        end

        // Store BRESP code — scb_release_mshr uses it for LRU update
        scb_mshr[mshr_idx].resp_code = m_write_resp_tx.bresp;

        // Release MSHR: applies buffered wdata, sets L3_DIRTY, updates LRU
        scb_release_mshr(mshr_idx, 1 /*resp_accepted*/);

        `uvm_info("WR_MISS_COMPLETE",
          $sformatf("M[%0d] S[%0d] BID=0x%0h MSHR[%0d] released — write-miss cycle complete BRESP=0x%0h",
                    m_idx, s_idx, m_write_resp_tx.bid, mshr_idx, m_write_resp_tx.bresp),
          UVM_MEDIUM)

      end else begin
        //-------------------------------------------------------------
        // WRITE HIT COMPLETION
        // No MSHR exists. Data was already merged in Master W channel.
        //-------------------------------------------------------------
        if(m_write_resp_tx.bresp != 2'b00) begin
          `uvm_error("HIT_BRESP_NOT_OKAY",
            $sformatf("M[%0d] S[%0d] BID=0x%0h write-hit BRESP=0x%0h expected OKAY",
                      m_idx, s_idx, m_write_resp_tx.bid, m_write_resp_tx.bresp))
        end

        `uvm_info("WR_HIT_COMPLETE",
          $sformatf("M[%0d] S[%0d] BID=0x%0h write-hit complete BRESP=0x%0h",
                    m_idx, s_idx, m_write_resp_tx.bid, m_write_resp_tx.bresp),
          UVM_MEDIUM)
      end

    end // forever
  join_none
end


//===========================================================================
// WRITE RESPONSE PATH - Slave Side
//===========================================================================
foreach(axi4_slave_write_response_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_write_resp_tx;
      bit           found;

      axi4_slave_write_response_analysis_fifo[s_idx].get(s_write_resp_tx);
      axi4_slave_tx_bresp_count[s_idx]++;
      total_slave_tx_count++;

      `uvm_info("SLV_WR_RESP",
        $sformatf("S[%0d] BID=0x%0h BRESP=0x%0h",
                  s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp),
        UVM_MEDIUM)

      found = 0;

      //=================================================================
      // WRITEBACK BRESP
      // Match: valid && needs_writeback && !wb_done && slave == s_idx
      //=================================================================
      for(int wi = 0; wi < MAX_MSHR; wi++) begin
        if(scb_mshr[wi].valid          &&
           scb_mshr[wi].needs_writeback &&
           !scb_mshr[wi].wb_done        &&
           scb_mshr[wi].slave == s_idx) begin

          if(s_write_resp_tx.bresp == 2'b00) begin
            // OKAY: writeback succeeded
            scb_mshr[wi].wb_done  = 1;
            scb_mshr[wi].wb_error = 0;

            `uvm_info("WB_BRESP_OK",
              $sformatf("S[%0d] MSHR[%0d] writeback BRESP=OKAY — refill AR unblocked", s_idx, wi),
              UVM_MEDIUM)
          end else begin
            // ERROR: writeback failed : Restore L3_DIRTY and undo Reference Data
            bit [ADDR_WIDTH-1:0] wb_addr;

            scb_mshr[wi].wb_done   = 1;
            scb_mshr[wi].wb_error  = 1;
            scb_mshr[wi].resp_code = s_write_resp_tx.bresp;

            l3_set_line_state(scb_mshr[wi].index, scb_mshr[wi].way, L3_DIRTY);

            wb_addr = {
              l3_cache[scb_mshr[wi].index][scb_mshr[wi].way].tag,
              scb_mshr[wi].index[L3_INDEX_BITS-1:0],
              {L3_OFFSET_BITS{1'b0}}
            };

            for(int b = 0; b < L3_CACHE_LINE_SIZE_BYTES; b++) begin
              if(referenceData[s_idx].exists(wb_addr + b))
                referenceData[s_idx].delete(wb_addr + b);
            end

            l3_writeback_errors++;

            `uvm_error("WB_BRESP_ERROR",
              $sformatf("S[%0d] MSHR[%0d] writeback BRESP=0x%0h — line restored DIRTY refMem undone",
                        s_idx, wi, s_write_resp_tx.bresp))
          end

          found = 1;
          break; 
        end
      end

      if(!found) begin
        `uvm_error("SLV_BRESP_UNEXPECTED",
          $sformatf("S[%0d] BID=0x%0h BRESP=0x%0h: received unexpected slave-side BRESP — no active writeback MSHR matches.",
                    s_idx, s_write_resp_tx.bid, s_write_resp_tx.bresp))
      end
    end // forever
  join_none
end
    
//===========================================================================
// READ ADDRESS PATH - Master Side
//===========================================================================
foreach(axi4_master_read_address_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx             m_read_addr_tx;
      int                        s_idx;
      pending_read_transaction_t pending_tx;
      bit                        expected_l3_hit;

      axi4_master_read_address_analysis_fifo[m_idx].get(m_read_addr_tx);
      axi4_master_tx_araddr_count[m_idx]++;

      `uvm_info("MSTR_RD_ADDR",
        $sformatf("M[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d ARSIZE=%0d "
                  "ARBURST=%0d ARCACHE=0x%0h",
                  m_idx, m_read_addr_tx.arid, m_read_addr_tx.araddr,
                  m_read_addr_tx.arlen, m_read_addr_tx.arsize,
                  m_read_addr_tx.arburst, m_read_addr_tx.arcache),
        UVM_MEDIUM)

      s_idx = get_slave_index(m_read_addr_tx.araddr);

      if(s_idx == -1) begin
        `uvm_error("ADDR_DECODE",
          $sformatf("M[%0d] ARADDR=0x%0h doesn't map to any slave",
                    m_idx, m_read_addr_tx.araddr))
        continue;
      end

      // L3 lookup — sets expected_l3_hit, allocates MSHR on miss
      l3_handle_read_request(m_idx, m_read_addr_tx, expected_l3_hit);

      // Arbitration tracking
      rr_read_pending_cnt[s_idx][m_idx]++;

      $cast(pending_tx.tx, m_read_addr_tx.clone());

      if(expected_l3_hit) begin

        bit [L3_TAG_BITS-1:0]    tag;
        bit [L3_INDEX_BITS-1:0]  index;
        bit [L3_OFFSET_BITS-1:0] offset;
        int                      hit_way;
        int                      bytes_per_beat;
        longint                  temp_addr;

        l3_cache_decode_address(m_read_addr_tx.araddr, tag, index, offset);

        // Find the way — same logic as comparison task
        hit_way = -1;
        for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
          if(l3_cache[index][w].valid                &&
             l3_cache[index][w].tag   == tag         &&
             l3_cache[index][w].state != L3_INVALID  &&
             l3_cache[index][w].state != L3_FILLING) begin
            hit_way = w;
            break;
          end
        end

        if(hit_way == -1) begin
          `uvm_error("L3_HIT_WAY_MISSING",
            $sformatf("M[%0d] Expected HIT but way not found at AR time "
                      "Addr=0x%0h", m_idx, m_read_addr_tx.araddr))
        end else begin

          bytes_per_beat = 1 << m_read_addr_tx.arsize;
          temp_addr      = m_read_addr_tx.araddr;

          pending_tx.tx.rdata = new[m_read_addr_tx.arlen + 1];

          foreach(pending_tx.tx.rdata[beat]) begin
            pending_tx.tx.rdata[beat] = '0;
            for(int byte_idx = 0; byte_idx < bytes_per_beat; byte_idx++) begin
              int line_offset = int'(temp_addr) % L3_CACHE_LINE_SIZE_BYTES;
              int lane        = int'(temp_addr) % (DATA_WIDTH/8);
              // data[] is flat byte array — index directly by line_offset
              pending_tx.tx.rdata[beat][8*lane +: 8] =
                l3_cache[index][hit_way].data[line_offset];
              temp_addr++;
            end
          end
        end

      end else begin
        // MISS: expected data from reference memory
        ref_model_read(pending_tx.tx, s_idx);
      end

      pending_tx.master_id         = m_idx;
      pending_tx.slave_id          = s_idx;
      pending_tx.expected_l3_hit   = expected_l3_hit;
      pending_tx.addr_request_time = $time;
      pending_tx.prediction_made   = 1;
      pending_tx.line_addr         = get_line_base_addr(m_read_addr_tx.araddr);

      if(expected_l3_hit) begin
        pending_tx.address_granted = 1;
      end else begin
        pending_tx.address_granted = 0;
      end

      pending_read_txns[s_idx][m_read_addr_tx.arid].push_back(pending_tx);

      // For hits: trigger grant event here since slave AR path is bypassed
      if(expected_l3_hit) begin
        ->slave_read_addr_granted[s_idx];
        `uvm_info("RD_HIT_GRANTED",
          $sformatf("M[%0d] S[%0d] ARID=0x%0h HIT — address_granted set "
                    "immediately, no slave AR expected",
                    m_idx, s_idx, m_read_addr_tx.arid),
          UVM_MEDIUM)
      end

      `uvm_info("RD_PENDING",
        $sformatf("M[%0d]->S[%0d] ARID=0x%0h queued (depth=%0d) "
                  "L3_HIT=%0b address_granted=%0b",
                  m_idx, s_idx, m_read_addr_tx.arid,
                  pending_read_txns[s_idx][m_read_addr_tx.arid].size(),
                  expected_l3_hit, pending_tx.address_granted),
        UVM_HIGH)

    end
  join_none
end
 
  //===========================================================================
  // READ ADDRESS PATH - Slave Side
  // Monitor slave read address acceptance and check arbitration
  //===========================================================================
  foreach(axi4_slave_read_address_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx s_read_addr_tx;
      pending_read_transaction_t pending_tx;
      int master_id;
      bit found;
      bit mshr_found;      // ADD: track MSHR binding result

      axi4_slave_read_address_analysis_fifo[s_idx].get(s_read_addr_tx);
      axi4_slave_tx_araddr_count[s_idx]++;

      `uvm_info("SLV_RD_ADDR",
               $sformatf("S[%0d] ARID=0x%0h ARADDR=0x%0h ARLEN=%0d",
                        s_idx, s_read_addr_tx.arid,
                        s_read_addr_tx.araddr, s_read_addr_tx.arlen),
               UVM_MEDIUM)

      found = 0;
      if(pending_read_txns[s_idx].exists(s_read_addr_tx.arid)) begin
        if(pending_read_txns[s_idx][s_read_addr_tx.arid].size() > 0) begin
          pending_tx = pending_read_txns[s_idx][s_read_addr_tx.arid][0];
          master_id  = pending_tx.master_id;
          found      = 1;

          check_read_rr_arbitration(s_idx, master_id);
          axi4_read_address_comparison(pending_tx.tx, s_read_addr_tx,
                                       master_id, s_idx);

          pending_tx.address_granted = 1;
          pending_read_txns[s_idx][s_read_addr_tx.arid][0] = pending_tx;
          ->slave_read_addr_granted[s_idx];

          `uvm_info("RD_ADDR_GRANTED",
                   $sformatf("S[%0d] M[%0d] ARID=0x%0h address granted",
                            s_idx, master_id, s_read_addr_tx.arid),
                   UVM_HIGH)
        end
      end

      if(!found) begin
        `uvm_error("RD_ADDR_NO_MATCH",
                  $sformatf("S[%0d] received ARID=0x%0h but no pending transaction",
                           s_idx, s_read_addr_tx.arid))
      end

      mshr_found = 0;

      // Guard: slave R-channel must not already be active
      if(active_r_valid[s_idx]) begin
        `uvm_error("AR_SLAVE_BUSY",
          $sformatf("S[%0d] received new AR but active_r_valid already set — "
                    "DUT issued two ARs on same slave channel",
                    s_idx))
      end else begin

        for(int m = 0; m < MAX_MSHR; m++) begin
          if(scb_mshr[m].valid                                          &&
             !scb_mshr[m].done                                         &&
             !scb_mshr[m].ar_sent                                      &&
             scb_mshr[m].slave   == s_idx                              &&
             scb_mshr[m].wb_done                                       &&
             scb_mshr[m].line_addr == get_line_base_addr(
                                        s_read_addr_tx.araddr)) begin

            // Bind this slave R-channel to this MSHR
            active_r_valid[s_idx]   = 1;
            active_r_mshr[s_idx]    = m;
            scb_mshr[m].ar_sent     = 1;
            mshr_found              = 1;

            `uvm_info("MSHR_AR_BOUND",
              $sformatf("S[%0d] AR bound to MSHR[%0d] line=0x%0h IsWrite=%0b",
                        s_idx, m, scb_mshr[m].line_addr,
                        scb_mshr[m].is_write),
              UVM_MEDIUM)
            break;
          end
        end

        // ── Validate: every slave AR must map to an MSHR ─────────────────
        // If no MSHR found, the DUT issued an AR that the scoreboard has
        // no record of — either a spurious fetch or an MSHR allocation was
        // missed in the master address path.
        if(!mshr_found) begin
          `uvm_error("AR_NO_MSHR",
            $sformatf("S[%0d] AR addr=0x%0h ARID=0x%0h has no matching MSHR — "
                      "spurious refill or missed miss allocation",
                      s_idx, s_read_addr_tx.araddr, s_read_addr_tx.arid))
        end
      end // active_r_valid guard
    end // forever
  join_none
end
  
  
 //===========================================================================
 // READ DATA PATH - Master Side     
 //===========================================================================
  foreach(axi4_master_read_data_analysis_fifo[i]) begin
  automatic int m_idx = i;
  fork
    forever begin
      axi4_master_tx             m_read_data_tx;
      pending_read_transaction_t pending_tx;
      int                        s_idx;
      bit                        found;

      axi4_master_read_data_analysis_fifo[m_idx].get(m_read_data_tx);
      axi4_master_tx_rdata_count[m_idx]++;
      axi4_master_tx_rresp_count[m_idx]++;

      `uvm_info("MSTR_RD_DATA",
        $sformatf("M[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s",
                  m_idx, m_read_data_tx.arid, m_read_data_tx.rdata[0],
                  m_read_data_tx.rlast, m_read_data_tx.rresp[0].name()),
        UVM_MEDIUM)

      // Search pending_read_txns across all slaves by arid and master_id
      s_idx = -1;
      for(int s = 0; s < NO_OF_SLAVES; s++) begin
        if(pending_read_txns[s].exists(m_read_data_tx.arid)) begin
          if(pending_read_txns[s][m_read_data_tx.arid].size() > 0) begin
            if(pending_read_txns[s][m_read_data_tx.arid][0].master_id == m_idx) begin
              s_idx = s;
              break;
            end
          end
        end
      end

      if(s_idx == -1) begin
        `uvm_error("RD_DATA_NO_SLAVE",
          $sformatf("M[%0d] RID=0x%0h cannot find slave for this transaction",
                    m_idx, m_read_data_tx.arid))
        continue;
      end

      // Wait for address grant on first beat only
      // For subsequent beats the grant is already set from the first beat
      @(slave_read_addr_granted[s_idx]);

      found = 0;

      if(pending_read_txns[s_idx].exists(m_read_data_tx.arid) &&
         pending_read_txns[s_idx][m_read_data_tx.arid].size() > 0) begin

        if(pending_read_txns[s_idx][m_read_data_tx.arid][0].address_granted) begin

          // PEEK at [0] — do NOT pop yet, transaction stays in queue
          // until rlast because subsequent beats need to match against it
          pending_tx = pending_read_txns[s_idx][m_read_data_tx.arid][0];

          if(pending_tx.master_id != m_idx) begin
            `uvm_error("RD_MASTER_MISMATCH",
              $sformatf("S[%0d] RID=0x%0h expected M[%0d] got M[%0d]",
                        s_idx, m_read_data_tx.arid,
                        pending_tx.master_id, m_idx))
          end

          // Compare this beat's data against expected
          // For hits: pending_tx.tx.rdata[] filled from cache at AR time
          // For misses: pending_tx.tx.rdata[] filled from referenceData at AR time
          axi4_read_data_comparison(
            pending_tx.tx,
            m_read_data_tx,
            m_idx,
            s_idx,
            pending_tx.expected_l3_hit
          );

          // On last beat: release MSHR and pop the pending transaction
          if(m_read_data_tx.rlast) begin

            // Release MSHR for misses only
            // Hits never allocated an MSHR so nothing to release
            if(!pending_tx.expected_l3_hit) begin
              int mshr_idx;
              mshr_idx = scb_find_existing_mshr(pending_tx.line_addr);

              if(mshr_idx != -1          &&
                 scb_mshr[mshr_idx].valid &&
                 scb_mshr[mshr_idx].done) begin

                scb_release_mshr(mshr_idx, 1);

                `uvm_info("MSHR_RELEASED",
                  $sformatf("M[%0d] S[%0d] MSHR[%0d] released after "
                            "master rlast confirmed line=0x%0h",
                            m_idx, s_idx, mshr_idx, pending_tx.line_addr),
                  UVM_MEDIUM)

              end else begin
                `uvm_error("MSHR_RELEASE_FAIL",
                  $sformatf("M[%0d] S[%0d] RID=0x%0h MSHR for "
                            "line=0x%0h not found or not done at rlast",
                            m_idx, s_idx, m_read_data_tx.arid,
                            pending_tx.line_addr))
              end
            end

            // NOW pop — transaction fully complete
            void'(pending_read_txns[s_idx][m_read_data_tx.arid].pop_front());

            byte_data_cmp_verified_rlast_count++;

            `uvm_info("RD_COMPLETE",
              $sformatf("S[%0d] M[%0d] RID=0x%0h complete L3_HIT=%0b",
                        s_idx, m_idx, m_read_data_tx.arid,
                        pending_tx.expected_l3_hit),
              UVM_MEDIUM)

          end

          found = 1;

        end else begin
          `uvm_error("RD_DATA_BEFORE_AR",
            $sformatf("M[%0d] S[%0d] RID=0x%0h read data before AR granted",
                      m_idx, s_idx, m_read_data_tx.arid))
        end
      end

      if(!found) begin
        `uvm_error("RD_DATA_NO_MATCH",
          $sformatf("M[%0d] RID=0x%0h S[%0d] no granted pending transaction",
                    m_idx, m_read_data_tx.arid, s_idx))
      end

    end // forever
  join_none
end
   
 //===========================================================================
 // READ DATA PATH - Slave Side     
 //===========================================================================
  foreach(axi4_slave_read_data_analysis_fifo[i]) begin
  automatic int s_idx = i;
  fork
    forever begin
      axi4_slave_tx        s_read_data_tx;
      int                  mshr_id;
      bit [ADDR_WIDTH-1:0] line_base;
      int                  index;
      int                  way;
      bit [1:0]            snap_resp_code;

      axi4_slave_read_data_analysis_fifo[s_idx].get(s_read_data_tx);
      axi4_slave_tx_rdata_count[s_idx]++;
      axi4_slave_tx_rresp_count[s_idx]++;

      `uvm_info("SLV_RD_DATA",
        $sformatf("S[%0d] RID=0x%0h RDATA[0]=0x%0h RLAST=%0b RRESP=%0s",
                  s_idx, s_read_data_tx.rid, s_read_data_tx.rdata[0],
                  s_read_data_tx.rlast, s_read_data_tx.rresp[0].name()),
        UVM_HIGH)

      if(!active_r_valid[s_idx]) begin
        `uvm_warning("SLV_RD_UNEXPECTED",
          $sformatf("S[%0d] read data beat but no active refill MSHR", s_idx))
        continue;
      end

      mshr_id = active_r_mshr[s_idx];

      if(s_read_data_tx.rresp[0] != 2'b00) begin
        scb_mshr[mshr_id].resp_code = s_read_data_tx.rresp[0];
        `uvm_error("REFILL_RRESP_ERROR",
          $sformatf("S[%0d] MSHR[%0d] beat=%0d RRESP=0x%0h",
                    s_idx, mshr_id,
                    scb_mshr[mshr_id].beat_count,
                    s_read_data_tx.rresp[0]))
      end

      scb_mshr[mshr_id].beat_count++;

      if(s_read_data_tx.rlast) begin

        // Beat count validation
        if(scb_mshr[mshr_id].beat_count != WORDS_PER_LINE) begin
          `uvm_error("REFILL_BEAT_COUNT",
            $sformatf("S[%0d] MSHR[%0d] RLAST after %0d beats expected %0d",
                      s_idx, mshr_id,
                      scb_mshr[mshr_id].beat_count,
                      WORDS_PER_LINE))
        end

        // Snapshot fields — needed for cache fill below
        line_base      = scb_mshr[mshr_id].line_addr;
        index          = scb_mshr[mshr_id].index;
        way            = scb_mshr[mshr_id].way;
        snap_resp_code = scb_mshr[mshr_id].resp_code;

        // Mark refill complete — MSHR stays alive until master R confirms
        scb_mshr[mshr_id].done = 1;

        // Fill scoreboard cache from referenceData only on success
        // MSHR is NOT released here — master R data path owns release
        if(snap_resp_code == 2'b00) begin

          for(int byte_i = 0; byte_i < L3_CACHE_LINE_SIZE_BYTES; byte_i++) begin
            if(referenceData[s_idx].exists(line_base + byte_i))
              l3_cache[index][way].data[byte_i] =
                referenceData[s_idx][line_base + byte_i];
            else
              l3_cache[index][way].data[byte_i] = 8'h00;
          end

          `uvm_info("L3_REFILL_COMPLETE",
            $sformatf("S[%0d] Cache filled from refMem: line=0x%0h "
                      "Set=%0d Way=%0d — awaiting master R response for MSHR release",
                      s_idx, line_base, index, way),
            UVM_MEDIUM)

        end else begin
          `uvm_info("L3_REFILL_ERROR_SKIP",
            $sformatf("S[%0d] MSHR[%0d] RRESP error — cache not installed",
                      s_idx, mshr_id),
            UVM_MEDIUM)
        end

      end // rlast

    end // forever
  join_none
end

endtask : run_phase
