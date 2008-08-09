open Verifast
open GMain

let show_ide path =
  let ctxts_lifo = ref None in
  let msg = ref None in
  let root = GWindow.window ~width:800 ~height:600 () in
  let actionGroup = GAction.action_group ~name:"Actions" () in
  let _ =
    let a = GAction.add_action in
    GAction.add_actions actionGroup [
      a "File" ~label:"_File";
      a "Save" ~stock:`SAVE ~accel:"<control>S";
      a "Verify" ~label:"_Verify";
      a "VerifyProgram" ~label:"Verify program" ~stock:`MEDIA_PLAY ~accel:"F5"
    ]
  in
  let ui = GAction.ui_manager() in
  ui#insert_action_group actionGroup 0;
  root#add_accel_group ui#get_accel_group;
  ui#add_ui_from_string "
    <ui>
      <menubar name='MenuBar'>
        <menu action='File'>
          <menuitem action='Save' />
        </menu>
        <menu action='Verify'>
          <menuitem action='VerifyProgram' />
        </menu>
      </menubar>
      <toolbar name='ToolBar'>
        <toolitem action='Save' />
        <toolitem action='VerifyProgram' />
      </toolbar>
    </ui>
  ";
  let rootVbox = GPack.vbox ~packing:root#add () in
  rootVbox#pack (ui#get_widget "/MenuBar");
  let toolbar = new GButton.toolbar (GtkButton.Toolbar.cast (ui#get_widget "/ToolBar")#as_widget) in
  toolbar#set_icon_size `SMALL_TOOLBAR;
  toolbar#set_style `ICONS;
  rootVbox#pack (toolbar#coerce);
  let rootTable = GPack.paned `VERTICAL ~border_width:3 ~packing:(rootVbox#pack ~expand:true) () in
  let _ = rootTable#set_position 350 in
  let textScroll = GBin.scrolled_window ~hpolicy:`AUTOMATIC ~vpolicy:`AUTOMATIC ~shadow_type:`IN () in
  let srcText = GText.view ~packing:textScroll#add () in
  let _ = (new GObj.misc_ops srcText#as_widget)#modify_font_by_name "Courier 10" in
  let _ = rootTable#pack1 ~resize:true ~shrink:true (textScroll#coerce) in
  let _ =
    let chan = open_in path in
    let buf = String.create 60000 in
    let gBuf = srcText#buffer in
    let gIter = gBuf#get_iter `START in
    let rec iter () =
      let result = input chan buf 0 60000 in
      if result = 0 then () else (gBuf#insert ~iter:gIter (String.sub buf 0 result); iter())
    in
    let _ = iter() in
    let _ = close_in chan in
    gBuf#set_modified false
  in
  let save() =
    let chan = open_out path in
    let gBuf = srcText#buffer in
    let text = gBuf#get_text () in
    output_string chan text;
    close_out chan;
    srcText#buffer#set_modified false
  in
  (actionGroup#get_action "Save")#connect#activate save;
  let updateWindowTitle() =
    let part1 = path ^ (if srcText#buffer#modified then " (Modified)" else "") in
    let part3 = match !msg with None -> "" | Some msg -> " - " ^ msg in
    root#set_title (part1 ^ " - VeriFast IDE" ^ part3)
  in
  let bottomTable = GPack.paned `HORIZONTAL () in
  let bottomTable2 = GPack.paned `HORIZONTAL () in
  let bottomTable3 = GPack.paned `HORIZONTAL () in
  let _ = bottomTable2#pack2 ~resize:true ~shrink:true (bottomTable3#coerce) in
  let _ = bottomTable#pack2 ~resize:true ~shrink:true (bottomTable2#coerce) in
  let _ = rootTable#pack2 ~resize:true ~shrink:true (bottomTable#coerce) in
  let create_listbox title column =
    let collist = new GTree.column_list in
    let col_k = collist#add Gobject.Data.int in
    let col_text = collist#add Gobject.Data.string in
    let store = GTree.list_store collist in
    let scrollWin = GBin.scrolled_window ~hpolicy:`AUTOMATIC ~vpolicy:`AUTOMATIC ~shadow_type:`IN () in
    let lb = GTree.view ~model:store ~packing:scrollWin#add () in
    lb#coerce#misc#modify_font_by_name "Sans 8";
    let col = GTree.view_column ~title:title ~renderer:(GTree.cell_renderer_text [], ["text", col_text]) () in
    let _ = lb#append_column col in
    (scrollWin, lb, col_k, col_text, col, store)
  in
  let (steplistFrame, stepList, stepKCol, stepCol, stepViewCol, stepStore) = create_listbox "Steps" 0 in
  let _ = bottomTable#pack1 ~resize:true ~shrink:true (steplistFrame#coerce) in
  let (assumptionsFrame, assumptionsList, assumptionsKCol, assumptionsCol, _, assumptionsStore) = create_listbox "Assumptions" 1 in
  let _ = bottomTable2#pack1 ~resize:true ~shrink:true (assumptionsFrame#coerce) in
  let (chunksFrame, chunksList, chunksKCol, chunksCol, _, chunksStore) = create_listbox "Heap chunks" 2 in
  let _ = bottomTable3#pack1 ~resize:true ~shrink:true (chunksFrame#coerce) in
  let (envFrame, envList, envKCol, envCol, _, envStore) = create_listbox "Locals" 3 in
  let _ = bottomTable3#pack2 ~resize:true ~shrink:true (envFrame#coerce) in
  let computeStepItems() =
    let ctxts_fifo = List.rev (match !ctxts_lifo with Some l -> l) in
    let rec iter ass ctxts =
      match ctxts with
        [] -> []
      | Assuming phi::cs -> iter (phi::ass) cs
      | Executing (h, env, l, msg)::cs -> (ass, h, env, l, msg)::iter ass cs
    in
    iter [] ctxts_fifo
  in
  let stepItems = ref None in
  let append_items (store:GTree.list_store) kcol col items =
    let rec iter k items =
      match items with
        [] -> ()
      | item::items ->
        let gIter = store#append() in
        store#set ~row:gIter ~column:kcol k;
        store#set ~row:gIter ~column:col item;
        iter (k + 1) items
    in
    iter 0 items
  in
  let updateStepList() =
    match !stepItems with
      None -> ()
    | Some stepItems ->
        append_items stepStore stepKCol stepCol (List.map (fun (ass, h, env, l, msg) -> msg) stepItems)
  in
  let clearStepInfo() =
    let gBuf = srcText#buffer in
    gBuf#remove_tag_by_name "currentLine" ~start:(gBuf#get_iter `START) ~stop:(gBuf#get_iter `END);
    assumptionsStore#clear();
    chunksStore#clear();
    envStore#clear()
  in
  let currentStepMark = srcText#buffer#create_mark (srcText#buffer#start_iter) in
  let stepSelected _ =
    match !stepItems with
      None -> ()
    | Some stepItems ->
      clearStepInfo();
      let [selpath] = stepList#selection#get_selected_rows in
      let k = let gIter = stepStore#get_iter selpath in stepStore#get ~row:gIter ~column:stepKCol in
      let (ass, h, env, l, msg) = List.nth stepItems k in
      let ((path1, line1, col1), (path2, line2, col2)) = l in
      let gBuf = srcText#buffer in
      let _ = gBuf#apply_tag_by_name "currentLine" ~start:(gBuf#get_iter(`LINECHAR (line1 - 1, col1 - 1))) ~stop:(gBuf#get_iter(`LINECHAR (line2 - 1, col2 - 1))) in
      let _ = gBuf#move_mark (`MARK currentStepMark) ~where:(gBuf#get_iter(`LINECHAR(line1 - 1, col1 - 1))) in
      let _ = srcText#scroll_to_mark ~within_margin:0.2 (`MARK currentStepMark) in
      let _ = append_items assumptionsStore assumptionsKCol assumptionsCol (List.map (fun phi -> pretty_print phi) (List.rev ass)) in
      let _ = append_items chunksStore chunksKCol chunksCol (List.map (fun (g, ts) -> g ^ "(" ^ pprint_ts ts ^ ")") h) in
      let _ = append_items envStore envKCol envCol (List.map (fun (x, t) -> x ^ "=" ^ pprint_t t) (remove_dups env)) in
      ()
  in
  let _ = srcText#buffer#create_tag ~name:"error" [`UNDERLINE `DOUBLE; `FOREGROUND "Red"] in
  let _ = srcText#buffer#create_tag ~name:"currentLine" [`BACKGROUND "Yellow"] in
  let _ = stepList#connect#cursor_changed ~callback:stepSelected in
  let _ = updateWindowTitle() in
  let _ = (new GObj.misc_ops stepList#as_widget)#grab_focus() in
  let updateStepListView() =
    let lastStepRowPath = stepStore#get_path (stepStore#iter_children ~nth:(stepStore#iter_n_children None - 1) None) in
    let _ = stepList#selection#select_path lastStepRowPath in
    stepList#scroll_to_cell lastStepRowPath stepViewCol;
    let (_, _, _, l, _) = match !stepItems with Some stepItems -> List.nth stepItems (List.length stepItems - 1) in
    let ((path1, line1, col1), (path2, line2, col2)) = l in
    let gBuf = srcText#buffer in
    srcText#buffer#apply_tag_by_name "error" ~start:(gBuf#get_iter(`LINECHAR (line1 - 1, col1 - 1))) ~stop:(gBuf#get_iter(`LINECHAR (line2 - 1, col2 - 1)))
  in
  let _ = root#event#connect#delete ~callback:(fun _ ->
    if srcText#buffer#modified then
      match GToolbox.question_box ~title:"VeriFast" ~buttons:["Save"; "Discard"; "Cancel"] "There are unsaved changes." with
        1 -> save(); false
      | 2 -> false
      | _ -> true
    else
      false
  ) in
  let _ = root#connect#destroy ~callback:GMain.Main.quit in
  let _ = srcText#buffer#connect#modified_changed (fun () ->
    updateWindowTitle()
  ) in
  let clearTrace() =
    clearStepInfo();
    stepStore#clear();
    let gBuf = srcText#buffer in
    srcText#buffer#remove_tag_by_name "error" ~start:gBuf#start_iter ~stop:gBuf#end_iter
  in
  let _ = srcText#buffer#connect#changed (fun () ->
    msg := None;
    stepItems := None;
    updateWindowTitle();
    clearTrace()
  ) in
  let handleStaticError ((_, line1, col1), (_, line2, col2)) emsg =
    let gBuf = srcText#buffer in
    gBuf#apply_tag_by_name "error" ~start:(gBuf#get_iter(`LINECHAR (line1 - 1, col1 - 1))) ~stop:(gBuf#get_iter(`LINECHAR (line2 - 1, col2 - 1)));
    msg := Some emsg;
    updateWindowTitle()
  in
  let verifyProgram() =
    save();
    clearTrace();
    try
      verify_program false path;
      msg := Some "0 errors found";
      updateWindowTitle()
    with
      ParseException (l, emsg) ->
      handleStaticError l ("Parse error" ^ (if emsg = "" then "." else ": " ^ emsg))
    | StaticError (l, emsg) ->
      handleStaticError l emsg
    | SymbolicExecutionError (ctxts, phi, l, emsg) ->
      ctxts_lifo := Some ctxts;
      msg := Some emsg;
      updateWindowTitle();
      stepItems := Some (computeStepItems());
      updateStepList();
      updateStepListView();
      stepSelected()
  in
  (actionGroup#get_action "VerifyProgram")#connect#activate verifyProgram;
  let _ = root#show() in
  (* This hack works around the problem that GText.text_view#scroll_to_mark does not seem to work if called before the GUI is running properly. *)
  Glib.Idle.add (fun () -> stepSelected(); false);
  GMain.main()

let _ =
  try
    match Sys.argv with
      [| _; path |] -> show_ide path
  with
    e -> GToolbox.message_box "VeriFast IDE" ("Exception during startup: " ^ Printexc.to_string e)