%/* Copyright (c) 2010, 2024, Oracle and/or its affiliates.
%
%   This program is free software; you can redistribute it and/or modify
%   it under the terms of the GNU General Public License, version 2.0,
%   as published by the Free Software Foundation.
%
%   This program is designed to work with certain software (including
%   but not limited to OpenSSL) that is licensed under separate terms,
%   as designated in a particular file or component or in included license
%   documentation.  The authors of MySQL hereby grant you an additional
%   permission to link the program and your derivative works with the
%   separately licensed software that they have either included with
%   the program or referenced in the documentation.
%
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License, version 2.0, for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with this program; if not, write to the Free Software
%   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */
%


%#include "xcom/xcom_vp_platform.h"

%#include "xcom/xcom_limits.h"
%#include "xcom/xcom_profile.h"
#ifdef RPC_XDR
%extern synode_no const null_synode;
%extern synode_no get_delivered_msg();
#endif

/*
The xcom protocol version numbers.

Zero is not used, so a zero protocol version indicates an error.
To add a new protocol version, add a new value to this enum.
To change an existing struct, add the new member with an #ifdef 
guard corresponding to the protocol version.
For example, to add a member corresponding to protocol version
x_1_7, the definition would look like this:
	
#if (XCOM_PROTO_VERS > 107) 
	new_member_t new_member; 
#else
#ifdef RPC_XDR 
%BEGIN 
%  if (xdrs->x_op == XDR_DECODE) {
%	 new_member = suitable_default_value;
%  }
%END
#endif
#endif

In this example, 107 corresponds to x_1_7.
The code in the BEGIN..END block will be inserted immediately before the 
final return in the generated xdr function. Members which are not in 
earlier protocol versions are not serialized, since they are excluded 
by the #if guard. When deserializing, the code in the BEGIN..END block 
takes care of insering a suitable value instead of actually reading 
the value from the serialized struct, since the earlier protocol 
version does not contain the new member.

After adding a new protocol version, set MY_XCOM_PROTO to this version in xcom_transport.cc (xcom_transport.cc:/MY_XCOM_PROTO)
In addition, the xdr_pax_msg, in this case xdr_pax_msg_1_7 must be added to the dispatch table pax_msg_func in xcom_transport.cc (xcom_transport.cc:/pax_msg_func)

For conversion of the new enum value to a string, add an entry in xcom_proto_to_str (xcom_vp_str.cc:/xcom_proto_to_str)

To actually generate the xdr functions for the new protocol version, see comments in rpcgen.cmake
*/

enum xcom_proto {
  x_unknown_proto = 0,
  x_1_0 = 1,
  x_1_1 = 2,
  x_1_2 = 3,
  x_1_3 = 4,
  x_1_4 = 5,
  x_1_5 = 6,
  x_1_6 = 7,
  x_1_7 = 8,
  x_1_8 = 9
};

enum delivery_status {
  delivery_ok = 0,
  delivery_failure = 1
};

/* Consensus type */
enum cons_type {
  cons_majority = 0          /* Plain majority */,
  cons_all = 1               /* Everyone must agree */
/*   cons_none = 2 */             /* NOT USED */
};

enum cargo_type {
  unified_boot_type = 0,
  xcom_boot_type = 1,
  xcom_set_group = 2,
/*   xcom_recover = 3, */
  app_type = 4,
/*   query_type = 5, */
/*   query_next_log = 6, */
  exit_type = 7,
  reset_type = 8,
  begin_trans = 9,
  prepared_trans = 10,
  abort_trans = 11,
  view_msg = 12,
  remove_reset_type = 13,
  add_node_type = 14,
  remove_node_type = 15,
  enable_arbitrator = 16,
  disable_arbitrator = 17,
  force_config_type = 18,
  x_terminate_and_exit = 19,
  set_cache_limit = 20,
  get_event_horizon_type = 21,
  set_event_horizon_type = 22,
  get_synode_app_data_type = 23,
  convert_into_local_server_type = 24,
  set_notify_truly_remove = 52
};

enum recover_action {
  rec_block = 0,
  rec_delay = 1,
  rec_send = 2
};

enum pax_op {
  client_msg = 0,
  initial_op = 1,
  prepare_op = 2,
  ack_prepare_op = 3,
  ack_prepare_empty_op = 4,
  accept_op = 5,
  ack_accept_op = 6,
  learn_op = 7,
  recover_learn_op = 8,
  multi_prepare_op = 9,
  multi_ack_prepare_empty_op = 10,
  multi_accept_op = 11,
  multi_ack_accept_op = 12,
  multi_learn_op = 13,
  skip_op = 14,
  i_am_alive_op = 15,
  are_you_alive_op = 16,
  need_boot_op = 17,
  snapshot_op = 18,
  die_op = 19,
  read_op = 20,
  gcs_snapshot_op = 21,
  xcom_client_reply = 22,
  tiny_learn_op = 23,
  LAST_OP
};

enum pax_msg_type {
  normal = 0,
  no_op = 1,
  multi_no_op = 2
};

enum client_reply_code {
     REQUEST_OK = 0,
     REQUEST_FAIL = 1,
     REQUEST_RETRY = 2
};

enum start_t {
     IDLE = 0,
     BOOT = 1,
     RECOVER = 2
};

typedef uint32_t xcom_event_horizon;

typedef uint32_t node_no;

typedef bool node_set<NSERVERS>;

/* A portable bit set */

typedef uint32_t bit_mask;

struct bit_set {
  bit_mask bits<NSERVERS>;
};

%#define	BITS_PER_BYTE 8
%#define	MASK_BITS	((bit_mask)(sizeof (bit_mask) * BITS_PER_BYTE))	/* bits per mask */
%#define	howmany_words(x, y)	(((x)+((y)-1))/(y))
%

%#define BIT_OP(__n, __p, __op, __inv) ((__p)->bits.bits_val[(__n)/MASK_BITS] __op  __inv (1u << ((__n) % MASK_BITS)))
%#define BIT_XOR(__n, __p) BIT_OP(__n, __p, ^=,(bit_mask))
%#define BIT_SET(__n, __p) BIT_OP(__n, __p, |=,(bit_mask))
%#define BIT_CLR(__n, __p) BIT_OP(__n, __p, &=,(bit_mask) ~)
%#define BIT_ISSET(__n, __p) (BIT_OP(__n, __p, &,(bit_mask)) != 0ul)
%#define BIT_ZERO(__p) memset((__p)->bits.bits_val, 0, (__p)->bits.bits_len * sizeof(*(__p)->bits.bits_val))

%extern bit_set *new_bit_set(uint32_t bits);
%extern bit_set *clone_bit_set(bit_set *orig);
%extern void free_bit_set(bit_set *bs);

%#ifndef CHECKED_DATA
%#define CHECKED_DATA
%typedef struct {
%	u_int data_len;
%	char *data_val;
%} checked_data;
%extern  bool_t xdr_checked_data (XDR *, checked_data*);
%#endif

struct blob {
	opaque data<MAXBLOB>;
};

struct x_proto_range {
	xcom_proto min_proto;
	xcom_proto max_proto;
};

/* Message number will wrap in 5.8E5 years if we run at 1000000 messages per second */
/* Change to circular hyper int if this is not desirable */

struct synode_no {
  uint32_t group_id; /* The group this synode belongs to */
  node_no node;         /* Node number */
  uint64_t msgno; /* Monotonically increasing number */
};

struct trans_id{
  synode_no cfg;
  uint32_t pc;
};

struct node_address{
	x_proto_range proto; /* Supported protocols */
	string address<MAXNAME>;
	blob  uuid;
};

typedef node_address node_list<NSERVERS>;

typedef node_no node_no_array<NSERVERS>;
typedef synode_no synode_no_array<MAX_SYNODE_ARRAY>;

struct uncommitted_list{
  uint32_t active;
  synode_no_array vers;
};

struct repository {
  synode_no vers;
  synode_no_array msg_list;
  uncommitted_list u_list;
};

struct x_error
{
  int32_t nodeid;
  int32_t code;
  string message<MAXERROR>;
};

struct trans_data{
  trans_id tid;
  int32_t pc;
  string cluster_name<MAXNAME>;
  x_error errmsg;
};

#define MAX_IP_PORT_LEN 64

/* Application-specific data */
union app_u switch(cargo_type c_t){
 case unified_boot_type:
 case add_node_type:
 case remove_node_type:
 case force_config_type:
 case xcom_boot_type:
 case xcom_set_group:
   node_list nodes;
 case app_type:
   checked_data data;
 case exit_type:
 case reset_type:
   void;
 case remove_reset_type:
   void;
 case begin_trans:
   void;
 case prepared_trans:
 case abort_trans:
   trans_data td;
 case view_msg:
   node_set present;
 case set_cache_limit:
   uint64_t cache_limit;
 case get_event_horizon_type:
   void;
 case set_event_horizon_type:
   xcom_event_horizon event_horizon;
 case get_synode_app_data_type:
   synode_no_array synodes;
 case convert_into_local_server_type:
   void;
 case set_notify_truly_remove:
   char ip_port[MAX_IP_PORT_LEN];
 default:
   void;
};

struct app_data{
  synode_no unique_id; /* Unique id of message */
  synode_no app_key;   /* Typically message number/log sequence number, but could be object ID  */
  uint64_t lsn; /* Local sequence number */
  uint32_t group_id; /* Unique ID shared by our group */
  cons_type consensus; /* Type of consensus needed for delivery of this message */
  bool chosen; /* Finished phase 3, may be executed */
  recover_action recover; /* Sent as part of recovery */
  app_u body;
  app_data *next; /* Link to next in list */
};

typedef app_data *app_data_ptr;
typedef app_data_ptr app_data_ptr_array<MAX_APP_PTR_ARRAY>;
typedef app_data_ptr *app_data_list;

struct key_range{
    synode_no k1;
    synode_no k2;
};

/* Ballot defined by count and node number */
struct ballot{
  int32_t cnt;
  node_no node;
};

struct snapshot{
  synode_no vers;
  app_data_ptr_array snap;
  uncommitted_list u_list;
};

struct config {
	synode_no start; 	/* Config is active from this message number */
	synode_no boot_key; /* The message number of the original unified_boot */
	node_list nodes;	/* Set of nodes in this config */
	node_set global_node_set; /* The global node set for this site */
	xcom_event_horizon event_horizon;
};

typedef config *config_ptr;
typedef config_ptr configs<MAX_SITE_DEFS>;

struct gcs_snapshot{
  synode_no log_start;
  synode_no log_end;
  configs cfg;
  blob app_snap;
};

struct synode_app_data {
   checked_data data;
   synode_no synode;
};
typedef synode_app_data synode_app_data_array<MAX_SYNODE_ARRAY>;

struct pax_msg{
  pax_op op;
  int32_t refcnt;
  node_no to;
  node_no from;
  short msg_type;
  short cli_err;
  short force_delivery;
  short group_id;
  xcom_event_horizon event_horizon;
  uint32_t reserved;
  synode_no max_synode;
  synode_no synode;
  synode_no delivered_msg;
  ballot reply_to;
  ballot proposal;
  app_data *a;
  snapshot *snap;
  gcs_snapshot *gcs_snap;
  synode_app_data_array requested_synode_app_data;
};
