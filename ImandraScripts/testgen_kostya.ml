#use "topfind";;
#require "yojson";;

:load Model/CME_Types.ml
:load Model/CME_Exchange.ml
:load Model/CME.ml

:load_ocaml Printers/CME_json.ml

(*
:load_ocaml CME_printers.ml
:load_ocaml CME_test_helper.ml
:load_ocaml kojson.ml
:load_ocaml CME_json.ml
:load_ocaml CME_test_printer_del.ml
*)

:adts
:p (in-theory (enable IML-ADT-EXECUTABLE-COUNTERPARTS-THEORY))


let int_of_book_reset x = match x with ST_BookReset -> 1 | _ -> 0 ;;


let four (m1, m2, m3, m4 : int_state_trans * int_state_trans * int_state_trans * int_state_trans) = true ;;

let valid_trans_4_s (s1, s2, s3, s4, m1, m2, m3, m4) = 
    is_trans_valid (s1, m1)
    && is_trans_valid (s2, m2)
    && is_trans_valid (s3, m3)
    && is_trans_valid (s4, m4)
;;

(** Are these transitions valid? *)
let valid_trans_4 (m1, m2, m3, m4 : int_state_trans * int_state_trans * int_state_trans * int_state_trans) = 
    let s1  = init_ex_state in 
    let s2  = process_int_trans (s1, m1) in 
    let s3  = process_int_trans (s2, m2) in 
    let s4  = process_int_trans (s3, m3) in 
    valid_trans_4_s (s1, s2, s3, s4, m1, m2, m3, m4)
;;

let valid_4_limit_resets (m1, m2, m3, m4 : int_state_trans * int_state_trans * int_state_trans * int_state_trans) =   
  (* No more than two resets *)
  int_of_book_reset m1 + int_of_book_reset m2 + int_of_book_reset m3 + int_of_book_reset m4 <= 2
  (* Transitions valid *)
  && valid_trans_4 (m1,m2,m3,m4)
;;


:shadow off

let end_reg = ref [];;
let str_reg = ref [];;

let pipe_to_model (m1, m2, m3, m4 : int_state_trans * int_state_trans * int_state_trans * int_state_trans) =
    let exchange_state = simulate_exchange ( init_ex_state , [m1; m2; m3; m4] ) in
    let pq = exchange_state.pac_queue in
    if pq = [] then () else
    let s = { 
        feed_sec_id   = get_security_id (exchange_state, SecA);
        feed_sec_type = SecA;
        books = { 
            book_depth = 4;
            multi    = { buys = []; sells = [] };
            implied  = { buys = []; sells = [] };
            combined = { buys = []; sells = [] };
            b_status = Empty ;
        };
        (* Communication channels *)
        channels = {
            unprocessed_packets = List.tl pq;
            current_packet = List.hd pq;

            processed_messages = [];
            processed_ref_a    = [];
            processed_ref_b    = [];
            processed_snap_a   = [];
            processed_snap_b   = [];

            cycle_hist_a = clean_cycle_hist;
            cycle_hist_b = clean_cycle_hist;
            last_seq_processed = -1;    
            cache = [];       
            last_snapshot = None;
        };
        feed_status = Normal;
        internal_changes = [];
        cur_time = 0;
    } in
    let () = str_reg := s :: !str_reg in 
    let s = simulate s in
    let out_json : Yojson.Basic.json = `Assoc [
        ( "ref_a", s.channels.processed_ref_a  |> packets_to_json );
        ( "ref_b", s.channels.processed_ref_b  |> packets_to_json );
        ("snap_a", s.channels.processed_snap_a |> packets_to_json );
        ("snap_b", s.channels.processed_snap_b |> packets_to_json );
    ] in
    let () = end_reg := s :: !end_reg in 
    out_json |> Yojson.Basic.pretty_to_string |> print_string 
;;

:shadow on

(* Let's set max_region_time! *)
(* :max_region_time 5 *)

:max_region_time 5
:max_regions 50       (* Limiting # regions to 50 so you can quickly see some results *)

:testgen four assuming valid_4_limit_resets with_code pipe_to_model
 

