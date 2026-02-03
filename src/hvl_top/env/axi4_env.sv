`ifndef AXI4_ENV_INCLUDED_
`define AXI4_ENV_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_env
// Description:
// Environment contains master agents, slave agents, virtual sequencer, and scoreboard
// Enhanced for multi-master multi-slave interconnect verification
//--------------------------------------------------------------------------------------------
class axi4_env extends uvm_env;
  `uvm_component_utils(axi4_env)
  
  //-------------------------------------------------------
  // Configuration Handles
  //-------------------------------------------------------
  
  // Variable: axi4_env_cfg_h
  // Handle for environment configuration object
  axi4_env_config axi4_env_cfg_h;

  // Variable: axi4_master_agent_cfg_h
  // Array of handles for master agent configurations
  axi4_master_agent_config axi4_master_agent_cfg_h[];

  // Variable: axi4_slave_agent_cfg_h
  // Array of handles for slave agent configurations
  axi4_slave_agent_config axi4_slave_agent_cfg_h[];

  //-------------------------------------------------------
  // Agent Handles (Arrays for Multi-Master/Multi-Slave)
  //-------------------------------------------------------
  
  // Variable: axi4_master_agent_h
  // Array of master agent handles
  axi4_master_agent axi4_master_agent_h[];
 
  // Variable: axi4_slave_agent_h
  // Array of slave agent handles
  axi4_slave_agent axi4_slave_agent_h[];

  //-------------------------------------------------------
  // Virtual Sequencer Handle
  //-------------------------------------------------------
  
  // Variable: axi4_virtual_seqr_h
  // Handle for virtual sequencer (contains arrays of sequencer handles)
  axi4_virtual_sequencer axi4_virtual_seqr_h;

  //-------------------------------------------------------
  // Scoreboard Handle
  //-------------------------------------------------------
  
  // Variable: axi4_scoreboard_h
  // Handle for scoreboard (contains arrays of FIFOs and exports)
  axi4_scoreboard axi4_scoreboard_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "axi4_env", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);

endclass : axi4_env

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
// name - axi4_env
// parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function axi4_env::new(string name = "axi4_env", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// Description:
// Create required components including arrays of master and slave agents
//
// Parameters:
// phase - uvm phase
//--------------------------------------------------------------------------------------------
function void axi4_env::build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  //-------------------------------------------------------
  // Get Environment Configuration
  //-------------------------------------------------------
  if(!uvm_config_db#(axi4_env_config)::get(this, "", "axi4_env_config", axi4_env_cfg_h)) begin
    `uvm_fatal("FATAL_ENV_CONFIG", "Couldn't get the axi4_env_config from config_db")
  end
  
  `uvm_info(get_type_name(), $sformatf("Environment Configuration: %0d Masters, %0d Slaves", 
           axi4_env_cfg_h.no_of_masters, axi4_env_cfg_h.no_of_slaves), UVM_LOW)
  
  //-------------------------------------------------------
  // Create and Get Master Agent Configurations
  //-------------------------------------------------------
  axi4_master_agent_cfg_h = new[axi4_env_cfg_h.no_of_masters];
  
  foreach(axi4_master_agent_cfg_h[i]) begin
    if(!uvm_config_db#(axi4_master_agent_config)::get(this, "", 
       $sformatf("axi4_master_agent_config[%0d]", i), axi4_master_agent_cfg_h[i])) begin
      `uvm_fatal("FATAL_MA_AGENT_CONFIG", 
                 $sformatf("Couldn't get axi4_master_agent_config[%0d] from config_db", i))
    end
    `uvm_info(get_type_name(), $sformatf("Got master_agent_config[%0d]", i), UVM_HIGH)
  end

  //-------------------------------------------------------
  // Create and Get Slave Agent Configurations
  //-------------------------------------------------------
  axi4_slave_agent_cfg_h = new[axi4_env_cfg_h.no_of_slaves];
  
  foreach(axi4_slave_agent_cfg_h[i]) begin
    if(!uvm_config_db#(axi4_slave_agent_config)::get(this, "", 
       $sformatf("axi4_slave_agent_config[%0d]", i), axi4_slave_agent_cfg_h[i])) begin
      `uvm_fatal("FATAL_SA_AGENT_CONFIG", 
                 $sformatf("Couldn't get axi4_slave_agent_config[%0d] from config_db", i))
    end
    `uvm_info(get_type_name(), $sformatf("Got slave_agent_config[%0d]", i), UVM_HIGH)
  end

  //-------------------------------------------------------
  // Create Master Agents Array
  //-------------------------------------------------------
  axi4_master_agent_h = new[axi4_env_cfg_h.no_of_masters];
  
  foreach(axi4_master_agent_h[i]) begin
    axi4_master_agent_h[i] = axi4_master_agent::type_id::create(
      $sformatf("axi4_master_agent_h[%0d]", i), this
    );
    `uvm_info(get_type_name(), $sformatf("Created master_agent[%0d]", i), UVM_HIGH)
  end

  //-------------------------------------------------------
  // Create Slave Agents Array
  //-------------------------------------------------------
  axi4_slave_agent_h = new[axi4_env_cfg_h.no_of_slaves];
  
  foreach(axi4_slave_agent_h[i]) begin
    axi4_slave_agent_h[i] = axi4_slave_agent::type_id::create(
      $sformatf("axi4_slave_agent_h[%0d]", i), this
    );
    `uvm_info(get_type_name(), $sformatf("Created slave_agent[%0d]", i), UVM_HIGH)
  end
  
  //-------------------------------------------------------
  // Create Virtual Sequencer (if enabled)
  //-------------------------------------------------------
  if(axi4_env_cfg_h.has_virtual_seqr) begin
    axi4_virtual_seqr_h = axi4_virtual_sequencer::type_id::create("axi4_virtual_seqr_h", this);
    `uvm_info(get_type_name(), "Created virtual sequencer", UVM_LOW)
  end

  //-------------------------------------------------------
  // Create Scoreboard (if enabled)
  //-------------------------------------------------------
  if(axi4_env_cfg_h.has_scoreboard) begin
    axi4_scoreboard_h = axi4_scoreboard::type_id::create("axi4_scoreboard_h", this);
    `uvm_info(get_type_name(), "Created scoreboard", UVM_LOW)
  end
  
  //-------------------------------------------------------
  // Assign Configurations to Master Agents
  //-------------------------------------------------------
  foreach(axi4_master_agent_h[i]) begin
    axi4_master_agent_h[i].axi4_master_agent_cfg_h = axi4_master_agent_cfg_h[i];
    // Set master ID in configuration
    axi4_master_agent_cfg_h[i].master_id = i;
    `uvm_info(get_type_name(), $sformatf("Assigned config to master_agent[%0d] with master_id=%0d", 
             i, i), UVM_HIGH)
  end
  
  //-------------------------------------------------------
  // Assign Configurations to Slave Agents
  //-------------------------------------------------------
  foreach(axi4_slave_agent_h[i]) begin
    axi4_slave_agent_h[i].axi4_slave_agent_cfg_h = axi4_slave_agent_cfg_h[i];
    // Set slave ID in configuration
    axi4_slave_agent_cfg_h[i].slave_id = i;
    `uvm_info(get_type_name(), $sformatf("Assigned config to slave_agent[%0d] with slave_id=%0d", 
             i, i), UVM_HIGH)
  end
  
  //-------------------------------------------------------
  // Pass Environment Config to Scoreboard
  //-------------------------------------------------------
  if(axi4_env_cfg_h.has_scoreboard) begin
    uvm_config_db#(axi4_env_config)::set(this, "axi4_scoreboard_h*", 
                                          "axi4_env_cfg_h", axi4_env_cfg_h);
  end
  
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// Description:
// Connect all components including arrays of agents to virtual sequencer and scoreboard
//
// Parameters:
// phase - uvm phase
//--------------------------------------------------------------------------------------------
function void axi4_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  //-------------------------------------------------------
  // Connect Virtual Sequencer (if enabled)
  //-------------------------------------------------------
  if(axi4_env_cfg_h.has_virtual_seqr) begin
    
    // Allocate sequencer handle arrays in virtual sequencer
    axi4_virtual_seqr_h.axi4_master_write_seqr_h = new[axi4_env_cfg_h.no_of_masters];
    axi4_virtual_seqr_h.axi4_master_read_seqr_h = new[axi4_env_cfg_h.no_of_masters];
    axi4_virtual_seqr_h.axi4_slave_write_seqr_h = new[axi4_env_cfg_h.no_of_slaves];
    axi4_virtual_seqr_h.axi4_slave_read_seqr_h = new[axi4_env_cfg_h.no_of_slaves];
    
    // Connect master sequencers to virtual sequencer
    foreach(axi4_master_agent_h[i]) begin
      axi4_virtual_seqr_h.axi4_master_write_seqr_h[i] = axi4_master_agent_h[i].axi4_master_write_seqr_h;
      axi4_virtual_seqr_h.axi4_master_read_seqr_h[i] = axi4_master_agent_h[i].axi4_master_read_seqr_h;
      `uvm_info(get_type_name(), $sformatf("Connected master_agent[%0d] sequencers to virtual sequencer", i), UVM_HIGH)
    end
    
    // Connect slave sequencers to virtual sequencer
    foreach(axi4_slave_agent_h[i]) begin
      axi4_virtual_seqr_h.axi4_slave_write_seqr_h[i] = axi4_slave_agent_h[i].axi4_slave_write_seqr_h;
      axi4_virtual_seqr_h.axi4_slave_read_seqr_h[i] = axi4_slave_agent_h[i].axi4_slave_read_seqr_h;
      `uvm_info(get_type_name(), $sformatf("Connected slave_agent[%0d] sequencers to virtual sequencer", i), UVM_HIGH)
    end
  end
  
  //-------------------------------------------------------
  // Connect Master Agents to Scoreboard (if enabled)
  //-------------------------------------------------------
  if(axi4_env_cfg_h.has_scoreboard) begin
    foreach(axi4_master_agent_h[i]) begin
      // Connect master monitor analysis ports to scoreboard FIFOs
      axi4_master_agent_h[i].axi4_master_mon_proxy_h.axi4_master_read_address_analysis_port.connect(
        axi4_scoreboard_h.axi4_master_read_address_analysis_fifo[i].analysis_export
      );
      
      axi4_master_agent_h[i].axi4_master_mon_proxy_h.axi4_master_read_data_analysis_port.connect(
        axi4_scoreboard_h.axi4_master_read_data_analysis_fifo[i].analysis_export
      );
      
      axi4_master_agent_h[i].axi4_master_mon_proxy_h.axi4_master_write_address_analysis_port.connect(
        axi4_scoreboard_h.axi4_master_write_address_analysis_fifo[i].analysis_export
      );
      
      axi4_master_agent_h[i].axi4_master_mon_proxy_h.axi4_master_write_data_analysis_port.connect(
        axi4_scoreboard_h.axi4_master_write_data_analysis_fifo[i].analysis_export
      );
      
      axi4_master_agent_h[i].axi4_master_mon_proxy_h.axi4_master_write_response_analysis_port.connect(
        axi4_scoreboard_h.axi4_master_write_response_analysis_fifo[i].analysis_export
      );
      
      `uvm_info(get_type_name(), $sformatf("Connected master_agent[%0d] to scoreboard", i), UVM_HIGH)
    end

    //-------------------------------------------------------
    // Connect Slave Agents to Scoreboard (if enabled)
    //-------------------------------------------------------
    foreach(axi4_slave_agent_h[i]) begin
      // Connect slave monitor analysis ports to scoreboard FIFOs
      axi4_slave_agent_h[i].axi4_slave_mon_proxy_h.axi4_slave_write_address_analysis_port.connect(
        axi4_scoreboard_h.axi4_slave_write_address_analysis_fifo[i].analysis_export
      );
      
      axi4_slave_agent_h[i].axi4_slave_mon_proxy_h.axi4_slave_write_data_analysis_port.connect(
        axi4_scoreboard_h.axi4_slave_write_data_analysis_fifo[i].analysis_export
      );
      
      axi4_slave_agent_h[i].axi4_slave_mon_proxy_h.axi4_slave_write_response_analysis_port.connect(
        axi4_scoreboard_h.axi4_slave_write_response_analysis_fifo[i].analysis_export
      );
      
      axi4_slave_agent_h[i].axi4_slave_mon_proxy_h.axi4_slave_read_address_analysis_port.connect(
        axi4_scoreboard_h.axi4_slave_read_address_analysis_fifo[i].analysis_export
      );
      
      axi4_slave_agent_h[i].axi4_slave_mon_proxy_h.axi4_slave_read_data_analysis_port.connect(
        axi4_scoreboard_h.axi4_slave_read_data_analysis_fifo[i].analysis_export
      );
      
      axi4_slave_agent_h[i].axi4_slave_drv_proxy_h.write_read_mode_h = axi4_env_cfg_h.write_read_mode_h;
      
      `uvm_info(get_type_name(), $sformatf("Connected slave_agent[%0d] to scoreboard", i), UVM_HIGH)
    end
    
    axi4_scoreboard_h.axi4_env_cfg_h = axi4_env_cfg_h;
  end
  
endfunction : connect_phase

`endif
