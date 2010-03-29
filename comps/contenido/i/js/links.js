function ShowDestAtom ( aDiv, i, nID, sClass, sName ) {

  var oFrame = parent.frames.sourcefrm.document;

  var tName = oFrame.createElement('p');
  tName.id = "dest_name_" + i;
  tName.className = "caption";
  tName.innerHTML = '<a href="/contenido/document.html?id=' + nID + '&class=' + sClass + '" target="_blank">' + sName + '</a> <span style="color:gray">(' + sClass + ')</span>&nbsp;';
  aDiv.appendChild(tName);

  var aDel = oFrame.createElement('a');
  aDel.id = 'del_item_' + i;
  aDel.href = 'javascript:RemoveDest(' + i + ')';
  aDel.style.color = 'red';
  aDel.innerHTML = '[x]';
  tName.appendChild(aDel);

  var iID = oFrame.createElement('input');
  iID.id = "dest_id_" + i;
  iID.name = "dest_id_" + i;
  iID.type = 'hidden';
  iID.value = nID;
  aDiv.appendChild(iID);

  var iClass = oFrame.createElement('input');
  iClass.id = "dest_class_" + i;
  iClass.name = "dest_class_" + i;
  iClass.type = 'hidden';
  iClass.value = sClass;
  aDiv.appendChild(iClass);

  var iName = oFrame.createElement('input');
  iName.id = "dest_name_" + i;
  iName.name = "dest_name_" + i;
  iName.type = 'hidden';
  iName.value = sName;
  aDiv.appendChild(iName);

}

function AppendDest ( nID, sClass, sName ) {
  var oFrame = parent.frames.sourcefrm.document;
  var oParent = oFrame.getElementById('link_list');
  var count = 0;
  for ( var i=0; i < 500; i++ ) {
	var oD = oFrame.getElementById("dest_id_" + i);
	var oC = oFrame.getElementById("dest_class_" + i);
	if ( oD && oC ) {
		count++;
		if ((oD.value == nID) && (oC.value == sClass)) {
			alert ('Элемент уже присутствует в списке');
			return false;
		}
	} else {
		break;
	}
  }

  var aDiv = oFrame.createElement('div');
  aDiv.id = "link_dest_" + count;
  aDiv.className = "link_string";
  oParent.appendChild(aDiv);
  ShowDestAtom ( aDiv, count, nID, sClass, sName );

  return false;
}

function RemoveDest ( nInd ) {
  var oFrame = parent.frames.sourcefrm.document;
  var oParent = oFrame.getElementById('link_list');
  var oForm = oFrame.forms['destform'];
  var Atom = new Array();
  var count = 0;
  for ( var i=0; i < 500; i++ ) {
	var sD = "dest_id_" + i;
	var sC = "dest_class_" + i;
	var sV = "dest_name_" + i;
	var oD = oForm.elements[sD];
	var oC = oForm.elements[sC];
	var oV = oForm.elements[sV];
	if ( oD && oC ) {
		if ( i != nInd ) {
			Atom[count++] = new Array (oD.value, oC.value, oV.value);
		}
	} else {
		break;
	}
  }
  oParent.innerHTML = '';
  for ( var i=0; i < count; i++ ) {
	var aDiv = document.createElement('div');
	aDiv.id = "link_dest_" + count;
	aDiv.className = "link_string";
	oParent.appendChild(aDiv);
	ShowDestAtom ( aDiv, i, Atom[i][0], Atom[i][1], Atom[i][2] );
  }
}



function ShowSourceAtom ( aDiv, i, nID, sClass, sName ) {

  var oFrame = parent.frames.destfrm.document;

  var tName = oFrame.createElement('p');
  tName.id = "source_name_" + i;
  tName.className = "caption";
  tName.innerHTML = '<a href="/contenido/document.html?id=' + nID + '&class=' + sClass + '" target="_blank">' + sName + '</a> <span style="color:gray">(' + sClass + ')</span>&nbsp;';
  aDiv.appendChild(tName);

  var aDel = oFrame.createElement('a');
  aDel.id = 'del_item_' + i;
  aDel.href = 'javascript:RemoveSource(' + i + ')';
  aDel.style.color = 'red';
  aDel.innerHTML = '[x]';
  tName.appendChild(aDel);

  var iID = oFrame.createElement('input');
  iID.id = "source_id_" + i;
  iID.name = "source_id_" + i;
  iID.type = 'hidden';
  iID.value = nID;
  aDiv.appendChild(iID);

  var iClass = oFrame.createElement('input');
  iClass.id = "source_class_" + i;
  iClass.name = "source_class_" + i;
  iClass.type = 'hidden';
  iClass.value = sClass;
  aDiv.appendChild(iClass);

  var iName = oFrame.createElement('input');
  iName.id = "source_name_" + i;
  iName.name = "source_name_" + i;
  iName.type = 'hidden';
  iName.value = sName;
  aDiv.appendChild(iName);

}

function AppendSource ( nID, sClass, sName ) {
  var oFrame = parent.frames.destfrm.document;
  var oParent = oFrame.getElementById('link_list');
  var count = 0;
  for ( var i=0; i < 500; i++ ) {
	var oD = oFrame.getElementById("source_id_" + i);
	var oC = oFrame.getElementById("source_class_" + i);
	if ( oD && oC ) {
		count++;
		if ((oD.value == nID) && (oC.value == sClass)) {
			alert ('Элемент уже присутствует в списке');
			return false;
		}
	} else {
		break;
	}
  }

  var aDiv = oFrame.createElement('div');
  aDiv.id = "link_source_" + count;
  aDiv.className = "link_string";
  oParent.appendChild(aDiv);
  ShowSourceAtom ( aDiv, count, nID, sClass, sName );

  return false;
}

function RemoveSource ( nInd ) {
  var oFrame = parent.frames.destfrm.document;
  var oParent = oFrame.getElementById('link_list');
  var oForm = oFrame.forms['sourceform'];
  var Atom = new Array();
  var count = 0;
  for ( var i=0; i < 500; i++ ) {
	var sD = "source_id_" + i;
	var sC = "source_class_" + i;
	var sV = "source_name_" + i;
	var oD = oForm.elements[sD];
	var oC = oForm.elements[sC];
	var oV = oForm.elements[sV];
	if ( oD && oC ) {
		if ( i != nInd ) {
			Atom[count++] = new Array (oD.value, oC.value, oV.value);
		}
	} else {
		break;
	}
  }
  oParent.innerHTML = '';
  for ( var i=0; i < count; i++ ) {
	var aDiv = document.createElement('div');
	aDiv.id = "link_source_" + count;
	aDiv.className = "link_string";
	oParent.appendChild(aDiv);
	ShowSourceAtom ( aDiv, i, Atom[i][0], Atom[i][1], Atom[i][2] );
  }
}
