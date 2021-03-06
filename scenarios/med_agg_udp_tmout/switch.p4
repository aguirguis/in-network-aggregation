/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define ENABLE_DEBUG_TABLES

#include "../includes/header.p4"
#include "../includes/parser.p4"
#include "../includes/ip_forward.p4"
#include "../includes/debug.p4"
#include "../includes/constants.p4"

// Learning parameters
const bit<32> DEFAULT_NODE_NUMBER = 5;
const bit<32> DEFAULT_ITERATIONS = 100;
const bit<32> DEFAULT_ETA = 1;
const bit<32> DEFAULT_INPUT_SIZE  = 200;
const bit<32> DEFAULT_INPUT_FEATURES  = 1;
const bit<32> DEFAULT_OUTPUT_CLASSES  = 1;
const bit<32> DEFAULT_SCALE_FACTOR  = 1000;

const bit<16> MCAST_GROUP  = 1;

#include "includes/aggregation.p4"

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    DebugIngress() debug_ingress;
    IPForward() ip_forward;
    Aggregation() aggregation;

    apply {
        if (hdr.agg.isValid()){
            aggregation.apply(hdr);
            standard_metadata.egress_spec = standard_metadata.ingress_port;
            debug_ingress.apply(hdr, meta, standard_metadata);
        } else if (hdr.ipv4.isValid()){
            ip_forward.apply(hdr, standard_metadata);
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/


control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    DebugEgress() debug_egress;

    action send_answer() {
        macAddr_t tmp_mac = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = tmp_mac;

        ip4Addr_t tmp_ip = hdr.ipv4.srcAddr;
        hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
        hdr.ipv4.dstAddr = tmp_ip;
        
        hdr.udp.dstPort = hdr.udp.srcPort;
        hdr.udp.srcPort = AGGREGATION_PORT;
        hdr.udp.checksum = 0;
    }

    apply {
        if (hdr.agg.isValid()) {
            send_answer();
            debug_egress.apply(hdr, meta, standard_metadata);
        }
     }
}



/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
