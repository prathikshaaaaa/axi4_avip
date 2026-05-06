`ifndef AXI4_GLOBALS_PKG_INCLUDED_
`define AXI4_GLOBALS_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package: axi4_globals_pkg
// Used for storing enums, parameters and defining the structs
//--------------------------------------------------------------------------------------------
package axi4_globals_pkg;

  //-------------------------------------------------------
  // Parameters used in axi4_avip are given below
  //-------------------------------------------------------
  //Parameter: MASTER_AGENT_ACTIVE
  //Used to set the master agent either active or passive
  parameter bit MASTER_AGENT_ACTIVE = 1;

  //Parameter: SLAVE_AGENT_ACTIVE
  //Used to set the slave agent either active or passive
  parameter bit SLAVE_AGENT_ACTIVE = 1;

  //Parameter: NO_OF_MASTERS
  //Used to set number of masters required
  parameter int NO_OF_MASTERS = 3;

  //Parameter: NO_OF_SLAVES
  //Used to set number of slaves required
  parameter int NO_OF_SLAVES = 2;

  //Parameter: ADDRESS_WIDTH
  //Used to set the address width to the address bus
  parameter int ADDRESS_WIDTH = 32;

  //Parameter: DATA_WIDTH
  //Used to set the data width 
  parameter int DATA_WIDTH = 32;
  
  parameter int ID_WIDTH = 4;

  //Parameter: SLAVE_MEMORY_SIZE
  //Sets the memory size of the slave in KB
  parameter int SLAVE_MEMORY_SIZE = 12;

  //Parameter: SLAVE_MEMORY_GAP
  //Sets the memory gap size of the slave
  parameter int SLAVE_MEMORY_GAP = 2;

  //Parameter: MEMORY_WIDTH
  //Sets the width it can store in each location
  parameter int MEMORY_WIDTH = 8;

  //Parameter: STROBE_WIDTH
  //Used to define the width of the strobes
  parameter int STROBE_WIDTH = (DATA_WIDTH/8);

  //Variable: MEM_ID
  //Indicates Slave Memory Depth 
  parameter int MEM_ID = 2**ADDRESS_WIDTH;

  //Variable: LENGTH
  //Indicates the length of the address write and read channels
  parameter int LENGTH = 8;

  // CACHE PARAMETERS
  parameter int CACHE_LINE_SIZE = 64;
  parameter int NUM_SETS = 64;
  parameter int ASSOCIATIVITY = 4;
  parameter int NUM_MSHR      = 8;
  parameter int WORDS_PER_LINE  = 4 ;

  //Variable: OUTSTANDING_FIFO_DEPTH
  //Indicates the fifo depth of outstanding transaction
  parameter int OUTSTANDING_FIFO_DEPTH = 16;
  parameter outstanding = 1; 
  parameter writeReadOrdering = 1;
  parameter activeTransactionCapacity = 2;
 
  //-------------------------------------------------------
  // Enums used in axi4_avip are given below
  //-------------------------------------------------------
  
  //Enum: awburst_e
  //Used to declare the enum type of write burst type
  typedef enum bit [1:0] {
    WRITE_FIXED    = 2'b00,
    WRITE_INCR     = 2'b01,
    WRITE_WRAP     = 2'b10,
    WRITE_RESERVED = 2'b11
  } awburst_e;

  //Enum: arburst_e
  //Used to declare the enum type of read burst type
  typedef enum bit [1:0] {
    READ_FIXED    = 2'b00,
    READ_INCR     = 2'b01,
    READ_WRAP     = 2'b10,
    READ_RESERVED = 2'b11
  } arburst_e;

  //Enum: transfer_size_e
  //Used to declare enum type for write transfer sizes
  typedef enum bit [2:0] {
    WRITE_1_BYTE    = 3'b000,
    WRITE_2_BYTES   = 3'b001,
    WRITE_4_BYTES   = 3'b010,
    WRITE_8_BYTES   = 3'b011,
    WRITE_16_BYTES  = 3'b100,
    WRITE_32_BYTES  = 3'b101,
    WRITE_64_BYTES  = 3'b110,
    WRITE_128_BYTES = 3'b111
  } awsize_e;

  //Enum: transfer_size_e
  //Used to declare enum type for read transfer sizes
  typedef enum bit [2:0] {
    READ_1_BYTE    = 3'b000,
    READ_2_BYTES   = 3'b001,
    READ_4_BYTES   = 3'b010,
    READ_8_BYTES   = 3'b011,
    READ_16_BYTES  = 3'b100,
    READ_32_BYTES  = 3'b101,
    READ_64_BYTES  = 3'b110,
    READ_128_BYTES = 3'b111
  } arsize_e;

  //Enum: awlock_e
  //Used to declare enum type for write lock access
  typedef enum bit {
    WRITE_NORMAL_ACCESS    = 1'b0,
    WRITE_EXCLUSIVE_ACCESS = 1'b1
  } awlock_e;

  //Enum: arlock_e
  //Used to declare enum type for read lock access
  typedef enum bit {
    READ_NORMAL_ACCESS    = 1'b0,
    READ_EXCLUSIVE_ACCESS = 1'b1
  } arlock_e;

  //Enum: awcache_e
  //Used to declare enum type for write cache access
  typedef enum bit [3:0] {
    WRITE_BUFFERABLE,
    WRITE_MODIFIABLE,
    WRITE_OTHER_ALLOCATE,
    WRITE_ALLOCATE,
    READ_WRITE_ALLOCATE = 15
  } awcache_e;

  //Enum: arcache_e
  //Used to declare enum type for read cache access
  typedef enum bit [3:0] {
    READ_BUFFERABLE,
    READ_MODIFIABLE,
    READ_OTHER_ALLOCATE,
    READ_ALLOCATE
  } arcache_e;

  //Enum: endian_e
  //Used to declare enum type for the endians
  typedef enum bit {
    BIG_ENDIAN    = 1'b0,
    LITTLE_ENDIAN = 1'b1
  } endian_e;

  //Enum: awprot_e 
  //Used to declare enum type of write protection of the transaction
  typedef enum bit [2:0] {
    WRITE_NORMAL_SECURE_DATA               = 3'b000,
    WRITE_NORMAL_SECURE_INSTRUCTION        = 3'b001,
    WRITE_NORMAL_NONSECURE_DATA            = 3'b010,
    WRITE_NORMAL_NONSECURE_INSTRUCTION     = 3'b011,
    WRITE_PRIVILEGED_SECURE_DATA           = 3'b100,
    WRITE_PRIVILEGED_SECURE_INSTRUCTION    = 3'b101,
    WRITE_PRIVILEGED_NONSECURE_DATA        = 3'b110,
    WRITE_PRIVILEGED_NONSECURE_INSTRUCTION = 3'b111
  } awprot_e;

  //Enum: arprot_e 
  //Used to declare enum type of read protection of the transaction
  typedef enum bit [2:0] {
    READ_NORMAL_SECURE_DATA               = 3'b000,
    READ_NORMAL_SECURE_INSTRUCTION        = 3'b001,
    READ_NORMAL_NONSECURE_DATA            = 3'b010,
    READ_NORMAL_NONSECURE_INSTRUCTION     = 3'b011,
    READ_PRIVILEGED_SECURE_DATA           = 3'b100,
    READ_PRIVILEGED_SECURE_INSTRUCTION    = 3'b101,
    READ_PRIVILEGED_NONSECURE_DATA        = 3'b110,
    READ_PRIVILEGED_NONSECURE_INSTRUCTION = 3'b111
  } arprot_e;

  //Enum: awid_e
  //Used to declare the enum type of write address id
  typedef enum bit [3:0] {
    AWID_0  = 16'd0,
    AWID_1  = 16'd1,
    AWID_2  = 16'd2,
    AWID_3  = 16'd3,
    AWID_4  = 16'd4,
    AWID_5  = 16'd5,
    AWID_6  = 16'd6,
    AWID_7  = 16'd7,
    AWID_8  = 16'd8,
    AWID_9  = 16'd9,
    AWID_10 = 16'd10,
    AWID_11 = 16'd11,
    AWID_12 = 16'd12,
    AWID_13 = 16'd13,
    AWID_14 = 16'd14,
    AWID_15 = 16'd15
  } awid_e;

  //Enum: bid_e
  //Used to declare the enum type of write response id
  typedef enum bit [15:0] {
    BID_0  = 16'd0,
    BID_1  = 16'd1,
    BID_2  = 16'd2,
    BID_3  = 16'd3,
    BID_4  = 16'd4,
    BID_5  = 16'd5,
    BID_6  = 16'd6,
    BID_7  = 16'd7,
    BID_8  = 16'd8,
    BID_9  = 16'd9,
    BID_10 = 16'd10,
    BID_11 = 16'd11,
    BID_12 = 16'd12,
    BID_13 = 16'd13,
    BID_14 = 16'd14,
    BID_15 = 16'd15
  } bid_e;

  //Enum: arid_e
  //Used to declare the enum type of read address id
  typedef enum bit[5:0] {
  ARID_0=0, ARID_1=1, ARID_2=2, ARID_3=3,
  ARID_4=4, ARID_5=5, ARID_6=6, ARID_7=7,
  ARID_8=8, ARID_9=9, ARID_10=10, ARID_11=11,
  ARID_12=12, ARID_13=13, ARID_14=14, ARID_15=15,
  ARID_16=16, ARID_17=17, ARID_18=18, ARID_19=19,
  ARID_20=20, ARID_21=21, ARID_22=22, ARID_23=23,
  ARID_24=24, ARID_25=25, ARID_26=26, ARID_27=27,
  ARID_28=28, ARID_29=29, ARID_30=30, ARID_31=31,
  ARID_32=32, ARID_33=33, ARID_34=34, ARID_35=35,
  ARID_36=36, ARID_37=37, ARID_38=38, ARID_39=39,
  ARID_40=40, ARID_41=41, ARID_42=42, ARID_43=43,
  ARID_44=44, ARID_45=45, ARID_46=46, ARID_47=47,
  ARID_48=48, ARID_49=49, ARID_50=50, ARID_51=51,
  ARID_52=52, ARID_53=53, ARID_54=54, ARID_55=55,
  ARID_56=56, ARID_57=57, ARID_58=58, ARID_59=59,
  ARID_60=60, ARID_61=61, ARID_62=62, ARID_63=63
} arid_e;

  //Enum: rid_e
  //Used to declare the enum type of read data/response id
  typedef enum bit [15:0] {
    RID_0  = 16'd0,   RID_1  = 16'd1,   RID_2  = 16'd2,   RID_3  = 16'd3,
    RID_4  = 16'd4,   RID_5  = 16'd5,   RID_6  = 16'd6,   RID_7  = 16'd7,
    RID_8  = 16'd8,   RID_9  = 16'd9,   RID_10 = 16'd10,  RID_11 = 16'd11,
    RID_12 = 16'd12,  RID_13 = 16'd13,  RID_14 = 16'd14,  RID_15 = 16'd15,
    RID_16 = 16'd16,  RID_17 = 16'd17,  RID_18 = 16'd18,  RID_19 = 16'd19,
    RID_20 = 16'd20,  RID_21 = 16'd21,  RID_22 = 16'd22,  RID_23 = 16'd23,
    RID_24 = 16'd24,  RID_25 = 16'd25,  RID_26 = 16'd26,  RID_27 = 16'd27,
    RID_28 = 16'd28,  RID_29 = 16'd29,  RID_30 = 16'd30,  RID_31 = 16'd31,
    RID_32 = 16'd32,  RID_33 = 16'd33,  RID_34 = 16'd34,  RID_35 = 16'd35,
    RID_36 = 16'd36,  RID_37 = 16'd37,  RID_38 = 16'd38,  RID_39 = 16'd39,
    RID_40 = 16'd40,  RID_41 = 16'd41,  RID_42 = 16'd42,  RID_43 = 16'd43,
    RID_44 = 16'd44,  RID_45 = 16'd45,  RID_46 = 16'd46,  RID_47 = 16'd47,
    RID_48 = 16'd48,  RID_49 = 16'd49,  RID_50 = 16'd50,  RID_51 = 16'd51,
    RID_52 = 16'd52,  RID_53 = 16'd53,  RID_54 = 16'd54,  RID_55 = 16'd55,
    RID_56 = 16'd56,  RID_57 = 16'd57,  RID_58 = 16'd58,  RID_59 = 16'd59,
    RID_60 = 16'd60,  RID_61 = 16'd61,  RID_62 = 16'd62,  RID_63 = 16'd63
} rid_e;

  //Enum: bresp_e
  //Used to declare the enum type of write response
  typedef enum bit [1:0] {
    WRITE_OKAY   = 2'b00,
    WRITE_EXOKAY = 2'b01,
    WRITE_SLVERR = 2'b10,
    WRITE_DECERR = 2'b11
  } bresp_e;

  //Enum: rresp_e
  //Used to declare the enum type of read response
  typedef enum bit [1:0] {
    READ_OKAY   = 2'b00,
    READ_EXOKAY = 2'b01,
    READ_SLVERR = 2'b10,
    READ_DECERR = 2'b11
  } rresp_e;

  //Enum: tx_type
  //Used to declare the type of transaction done
  typedef enum bit {
    WRITE = 1,
    READ  = 0
  } tx_type_e;

  //Enum : transfer_type_e
  //Used to the determine the type of the transfer
  typedef enum bit[1:0] {
    OUTSTANDING_WRITE      = 2'b00, 
    OUTSTANDING_READ       = 2'b01, 
    NON_OUTSTANDING_WRITE  = 2'b10, 
    NON_OUTSTANDING_READ   = 2'b11 
  }transfer_type_e;

  //Enum : read_data_type_mode_e
  //Used to the determine the type of the read data
  typedef enum bit[1:0] {
    RANDOM_DATA_MODE = 2'b00,
    SLAVE_MEM_MODE   = 2'b01,
    USER_DATA_MODE   = 2'b10,
    SLAVE_ERR_RESP_MODE = 2'b11
  } read_data_type_mode_e;

  //Enum : transfer_type_e  
  //Used to determine the mode for score board check 
  typedef enum bit[1:0] {
    ONLY_WRITE_DATA  = 2'b00,
    ONLY_READ_DATA   = 2'b01,
    WRITE_READ_DATA  = 2'b10
  } write_read_data_mode_e;
  
  //Enum : Response_mode_e  
  //Used to determine the mode of response to send
  typedef enum bit[1:0] {
    RESP_IN_ORDER                 = 2'b00,
    ONLY_READ_RESP_OUT_OF_ORDER   = 2'b01,
    WRITE_READ_RESP_OUT_OF_ORDER  = 2'b10,
    ONLY_WRITE_RESP_OUT_OF_ORDER  = 2'b11
  } response_mode_e;

  //Enum : QoS_mode_e
  typedef enum bit[1:0] {
    QOS_MODE_DISABLE            = 2'b00,
    ONLY_READ_QOS_MODE_ENABLE   = 2'b01,
    WRITE_READ_QOS_MODE_ENABLE  = 2'b10,
    ONLY_WRITE_QOS_MODE_ENABLE  = 2'b11
  } qos_mode_e;

  //Used to store the awid for Qos mode
  awid_e awid_queue_for_qos[$];

  //-------------------------------------------------------
  // Structs used in axi_avip are given below
  //-------------------------------------------------------
  
  //Struct: axi4_w_transfer_char_s
  //This struct datatype consists of all write signals which are used for seq item conversion
  typedef struct {
    //Write Address Channel Signals
    bit [($clog2(axi4_globals_pkg::NO_OF_MASTERS)+4)-1:0]               awid;
    bit [ADDRESS_WIDTH-1:0] awaddr;
    bit [7:0]               awlen;
    bit [2:0]               awsize;
    bit [1:0]               awburst;
    bit                     awlock;
    bit [3:0]               awcache;
    bit [3:0]               awqos;
    bit [3:0]               awregion;
    bit                     awuser;
    bit [2:0]               awprot;
    bit                     awvalid;
    bit	                    awready;
    //Write Data Channel Signals
    bit     [2**LENGTH:0][DATA_WIDTH-1:0] wdata;
    bit [2**LENGTH:0][(DATA_WIDTH/8)-1:0] wstrb;
    bit                     [2**LENGTH:0] wuser;
    bit                                   wlast;
    //Write Response Channel Signals
    bit [3:0] bid;
    bit [1:0] bresp;
    bit       buser;
    bit       bvalid;
    bit       tx_type; 
    int       wait_count_write_address_channel;
    int       wait_count_write_data_channel;
    int       wait_count_write_response_channel;
    int       outstanding_write_tx;
    int       no_of_wait_states;
  } axi4_write_transfer_char_s; 

  //Struct: axi4_r_transfer_char_s
  //This struct datatype consists of all read signals which are used for seq item conversion
  typedef struct {
    //Read Address Channel Signals
    bit [($clog2(axi4_globals_pkg::NO_OF_MASTERS)+4)-1:0] arid;
    bit [ADDRESS_WIDTH-1:0] araddr;
    bit               [7:0] arlen;
    bit               [2:0] arsize;
    bit               [1:0] arburst;
    bit               [3:0] arcache;
    bit               [2:0] arprot;
    bit               [3:0] arqos;
    bit               [3:0] arregion;
    bit               [3:0] aruser;
    bit                     arlock;
    //Read Data Channel Signals
    bit  [($clog2(axi4_globals_pkg::NO_OF_MASTERS)+4)-1:0] rid;
    bit [2**LENGTH:0][DATA_WIDTH-1:0] rdata;
    bit            [2**LENGTH:0][1:0] rresp; 
    bit            [2**LENGTH:0][3:0] ruser;
    bit                               rlast;
    bit                               rvalid;
    bit                               tx_type; 
    int                               wait_count_read_address_channel;
    int                               wait_count_read_data_channel;
    int                               outstanding_read_tx;
    int                               no_of_wait_states;
  } axi4_read_transfer_char_s;

  //Struct: axi4_cfg_char_s
  //This struct datatype consists of all configurations which are used for seq item conversion
  typedef struct {
    bit [ADDRESS_WIDTH-1:0] min_address;
    bit [ADDRESS_WIDTH-1:0] max_address;
    int                     wait_count_write_address_channel;
    int                     wait_count_write_data_channel;
    int                     wait_count_write_response_channel;
    int                     wait_count_read_address_channel;
    int                     wait_count_read_data_channel;
    int                     outstanding_write_tx;
    int                     outstanding_read_tx;
    response_mode_e         slave_response_mode;
    qos_mode_e              qos_mode_type;
  } axi4_transfer_cfg_s;

endpackage : axi4_globals_pkg

`endif

