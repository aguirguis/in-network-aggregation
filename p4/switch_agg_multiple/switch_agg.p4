/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"


const bit<32> MAX_COUNTER_VALUE = 1 << 16;
const bit<32> NODE_NUMBER = 3;




/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop();
    }
    
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        meta.index = (bit<32>)port;
        // meta.index = (bit<32>)((bit<16>)hdr.ipv4.dstAddr);
    }
    
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    apply {

        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    
    // Declarations

    // counter of nodes that I received the gradient from
    register<bit<32>>(MAX_COUNTER_VALUE) counter;

    // aggregated gradients from step-1
    register<bit<32>>(MAX_COUNTER_VALUE) aggregation;

    // aggregated gradiens being calculated  
    register<bit<32>>(NODE_NUMBER) gradients;


    action setCounter() {
        hdr.pcounter.setValid();
        hdr.pcounter.count = 0;
        hdr.pcounter.pid = hdr.ethernet.etherType;
        hdr.ethernet.etherType = TYPE_pcounter;
        packetCounter.write( meta.index, 0);

    }
    action addCounter() {
        // hdr.pcounter.count = hdr.pcounter.count + 1;
        // get register myCount
        packetCounter.read( tmp, meta.index);        
        // add myCount header
        hdr.pcounter.count = tmp+1;
        // sum to the register
        packetCounter.write(meta.index, tmp+1);
    }

    apply { 
         if (hdr.ipv4.isValid()){
            if (!hdr.pcounter.isValid()){
                setCounter();
            } 
            if (hdr.pcounter.isValid()) {
                addCounter();
            }
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
