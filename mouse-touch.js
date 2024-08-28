
/*
  Touch : start, end, move, cancel events, each has a 'changed touches' property

  Mouse : --auxclick --click --contextmenu --dblclick          mousedown
  mouseenter mouseleave mousemove mouseout mouseover mouseup
*/

// So use only mouse enter/leave, and mouse move
// Use button identifiers for creating different 'kinds' of mouse pointers


//A global state of touch:
//     or assume it moves as it enters?

//handler gets provided
// A> that touch/mouse event id : 'id'
// B> that touch/mouse type : 'type'
// C> that touch/mouse event relative offset as array of two coords: 'pos' 
// D> action , enter, move or leave
// E> key states of ctrl, shift, meta, alt 
function create_touch_and_mouse_events(object, handler){
    const glob_arr = new Map();
    
    function get_touch_offset(tch, tgt){
	const bcr = tgt.getBoundingClientRect();
	const x = tch.clientX - bcr.x;
	const y = tch.clientY - bcr.y;
	//console.log("bcr, x, y " + bcr + " " + bcr.x + " " + bcr.y + " " + x + " " + y);
	return [x, y];
    }
    function set_item(inx, item, val){
	if(glob_arr.get(inx) === undefined){
	    const da = {};
	    da["pos"] = [0,0];
	    da["inside"] = false;
	    glob_arr.set(inx, da);
	}
	const pval = glob_arr.get(inx);
	pval[item] = val;
	glob_arr.set(inx, pval);
    }
    function was_active(id){
	return ( glob_arr.get(id) !== undefined ) &&
	    ( glob_arr.get(id).inside === true );
    }

    function dump_arr(){
	return [...glob_arr.entries()].reduce((acc, x) => {
	    const d = x;
	    d[1].pos[0] = Math.floor(d[1].pos[0]);
	    d[1].pos[1] = Math.floor(d[1].pos[1]);
	    return acc + " " + JSON.stringify(d);
	}, "");
    }

    function make_event(type, id, action, event){
	const da_event = {
	    "id"     : id,
	    "type"   : type,
	    "action" : action,
	    "altKey" : event.altKey,
	    "metaKey" : event.metaKey,
	    "pos" : [],
	    "shiftKey" : event.shiftKey,
	    "ctrlKey" : event.ctrlKey
	};
	if(type === "mouse")
	    da_event.pos = [event.offsetX, event.offsetY];
	else{
	    for(let i = 0; i < event.touches.length; ++i){
		const tch = event.touches[i];
		if(tch.identifier == id)
		    da_event.pos = get_touch_offset(tch, object);
	    }
	    if(da_event.pos[0] === undefined){
		da_event.pos = glob_arr.get('t' + id).pos;
	    }
	}
	return da_event;
    }
    
    const m_enter = (evt) => {
	const nodef = [false];
	for(let i = 0; i < 10; ++i){
	    if((i == 0) || (0 != ((1<<(i-1)) & evt.buttons))){
		//Actually this should always be false
		const was_in = was_active('m'+i);

		set_item('m'+i, 'inside', true);
		set_item('m'+i, 'pos', [evt.offsetX, evt.offsetY]);
		if(!was_in)
		    nodef[0] = handler(make_event("mouse", i, "enter", evt)) || nodef[0];
	    }
	}
	//document.getElementById("s-rec").innerTex= dump_arr();
	if(nodef[0]) evt.preventDefault();
    };
    const t_enter = (evt) => {
	const nodef = [false];
	//Can just look at targetTouches
	for(let i = 0; i < evt.targetTouches.length; ++i){
	    const tch = evt.targetTouches[i];
	    const was_in = was_active('t'+tch.identifier);
	    
	    set_item('t'+tch.identifier, 'inside', true);
	    set_item('t'+tch.identifier, 'pos', get_touch_offset(tch, object));
	    if(!was_in)
		nodef[0] = handler(make_event("touch", tch.identifier, "enter", evt)) || nodef[0];
	}
	//document.getElementById("s-rec").innerText = dump_arr();
	if(nodef[0]) evt.preventDefault();
    };
    const t_end = (evt) => {
	const nodef = [false];
	for(let i = 0; i < evt.changedTouches.length; ++i){
	    const tch = evt.changedTouches[i];
	    if(was_active('t'+tch.identifier)){
		//set_item('t'+tch.identifier, 'moving', false);
		set_item('t'+tch.identifier, 'inside', false);
		nodef[0] = handler(make_event("touch", tch.identifier, "leave", evt)) || nodef[0];
	    }
	}
	//document.getElementById("s-rec").innerText = dump_arr();
	if(nodef[0]) evt.preventDefault();
    };
    const m_end = (evt) => {
	const nodef = [false];
	for(let i = 0; i < 10; ++i){
	    if(was_active('m'+i)){
		set_item('m'+i, 'inside', false);
		nodef[0] = handler(make_event("mouse", i, "leave", evt)) || nodef[0];
	    }
	    //set_item('m0', 'pos', [evt.offsetX, evt.offsetY]);
	}
	//document.getElementById("s-rec").innerText = dump_arr();
	if(nodef[0]) evt.preventDefault();
    };
    const t_move = (evt) => {
	const nodef = [false];
	const ids = [];
	for(let i = 0; i < evt.changedTouches.length; ++i){
	    const tch = evt.changedTouches[i];
	    ids.push(tch.identifier);
	}
	for(let i = 0; i < evt.targetTouches.length; ++i){
	    const tch = evt.targetTouches[i];
	    if(ids.find((x) => (x == tch.identifier)) !== undefined){
		//if(glob_arr.get('t'+tch.identifier).inside === true)
		const p = get_touch_offset(tch, object);
		const bb = object.getBoundingClientRect();
		const is_in = (p[0] <= bb.width) && (p[1] <= bb.height) &&
		      (p[0] >= 0) && (p[1] >= 0);
		const was_in = was_active('t'+tch.identifier);

		if(is_in){
		    set_item('t'+tch.identifier, 'pos',
			     get_touch_offset(tch, object));
		    if(!was_in){
			//Simulate touch enter event here
			set_item('t'+tch.identifier, 'inside', true);
			nodef[0] = handler(make_event("touch", tch.identifier, "enter", evt)) || nodef[0];
		    }
		    else
			nodef[0] = handler(make_event("touch", tch.identifier, "move", evt)) || nodef[0];
		}
		else if(!is_in && was_in){
		    //Simulate touch cancel event here
		    set_item('t'+tch.identifier, 'inside', false);
		    nodef[0] = handler(make_event("touch", tch.identifier, "leave", evt)) || nodef[0];
		}
	    }
	}
	//document.getElementById("s-rec").innerText = dump_arr();
	if(nodef[0]) evt.preventDefault();
    };
    const m_move = (evt) => {
	const nodef = [false];
	for(let i = 0; i < 10; ++i){
	    if((i == 0) || (0 != ((1<<(i-1)) & evt.buttons))){
		const was_in = was_active('m' + i);
		set_item('m'+i, 'inside', true);
		set_item('m'+i, 'pos', [evt.offsetX, evt.offsetY]);
		if(was_in)
		    nodef[0] = handler(make_event("mouse", i, "move", evt)) || nodef[0];
		else
		    nodef[0] = handler(make_event("mouse", i, "enter", evt)) || nodef[0];
		//set_item('m0', 'pos', [evt.offsetX, evt.offsetY]);
	    }
	    else{
		//Simulate mouse leave event here
		//if(glob_arr.get('m'+i) !== undefined){
		if(was_active('m'+i)){
		    set_item('m'+i, 'inside', false);
		    nodef[0] = handler(make_event("mouse", i, "leave", evt)) || nodef[0];
		}
	    }
	}
	//document.getElementById("s-rec").innerText = dump_arr();
	if(nodef[0]) evt.preventDefault();
    };
    const disable_context_menu = (evt) => {
	evt.preventDefault();
    };
    //Additional mouse down and up events
    const m_down = (evt) => {
	//console.log("The mousedown was triggered with buttons = " + evt.buttons);
	const nodef = [false];
	for(let i = 1; i < 10; ++i){
	    if(0 != ((1<<(i-1)) & evt.buttons)){
		//This should cause all other button enter to always be
		const was_in = was_active('m'+i);
		if(!was_in){
		    //Simulate mouse enter here
		    set_item('m'+i, 'inside', true);
		    set_item('m'+i, 'pos', [evt.offsetX, evt.offsetY]);
		    nodef[0] = handler(make_event("mouse", i, "enter", evt)) || nodef[0];
		}
	    }
	}
	if(nodef[0]) evt.preventDefault();
    };

    const m_up = (evt) => {
	//console.log("The mouseup was triggered with buttons = " + evt.buttons);
	const nodef = [false];
	for(let i = 1; i < 10; ++i){
	    if(0 == ((1<<(i-1)) & evt.buttons)){
		//This should cause all other button enter to always be
		const was_in = was_active('m'+i);
		if(was_in){
		    //Simulate mouse leave
		    set_item('m'+i, 'inside', false);
		    nodef[0] = handler(make_event("mouse", i, "leave", evt)) || nodef[0];
		}
	    }
	}

	object.removeEventListener("contextmenu", disable_context_menu);
	if(nodef[0]){
	    object.addEventListener("contextmenu", disable_context_menu);
	    evt.preventDefault();
	}

	//object.removeEventListener("contextmenu", disable_context_menu);
    };

    object.addEventListener("mouseenter", m_enter);
    object.addEventListener("touchstart", t_enter);
    object.addEventListener("touchend", t_end);
    object.addEventListener("touchcancel", t_end);
    object.addEventListener("mouseleave", m_end);
    object.addEventListener("touchmove", t_move);
    object.addEventListener("mousemove", m_move);
    object.addEventListener("mousedown", m_down);
    object.addEventListener("mouseup", m_up);

    return {
	"events" : glob_arr,
	"listeners" : {
	    "m_enter" : m_enter,
	    "t_enter" : t_enter,
	    "t_end" : t_end,
	    "m_end" : m_end,
	    "t_move" : t_move,
	    "m_move" : m_move,
	    "m_down" : m_down,
	    "m_up" : m_up
	},
    };
}
