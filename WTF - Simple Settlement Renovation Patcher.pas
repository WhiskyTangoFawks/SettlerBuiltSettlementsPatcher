unit userscript;

//Using the Script
//0- Enable the script template override plugin
//1- set the settlement value
//2- run on the worldspace section
//3- adjust COBJ component values
//4- Copy SMM menu stuff into the plugin

uses 'lib\mteFunctions';
const
  sFalloutMasterName = 'Fallout4.esm';
	sPatchAuthor = 'WhiskyTangoFox';
var
	masterFile, patch, slMasters, xmarker, cobj, acti: IInterface;
  initDone : boolean;
  settlement :String;
  
//============================================================================  
  function Initialize: integer;
var
  slMasters: IInterface;
  i: integer;
  
begin
  for i := 0 to Pred(FileCount) do begin
		// locate master files - This is required only for master files that contain new perk records we're using as requirements
		if SameText(GetFileName(FileByIndex(i)), 'SettlerBuiltSettlements.esp') then masterFile := FileByIndex(i);  
	end;

  if not assigned(masterFile) then raise Exception.Create('**ERROR** failed to assign master file');

  patch := CreatePatchPlugin();
  AddMasterIfMissing(patch, 'Fallout4.esm');
  AddMasterIfMissing(patch, 'DLCCoast.esm');
  AddMasterIfMissing(patch, 'DLCRobot.esm');
  AddMasterIfMissing(patch, 'DLCNukaWorld.esm');
  AddMasterIfMissing(patch, 'DLCWorkshop01.esm');
  AddMasterIfMissing(patch, 'DLCWorkshop02.esm');
  AddMasterIfMissing(patch, 'DLCWorkshop03.esm');
  AddMasterIfMissing(patch, 'SettlerBuiltSettlements.esp');

end;
  
  //============================================================================
function Finalize: integer;
var
  i, count: integer;
  components, componentAndCount: IInterface;
  gnam : string;

begin
	components := ElementByPath(cobj, 'FVPA - Components');
  for i := ElementCount(components)-1 downto 0 do begin
    componentAndCount := ElementByIndex(components, i);
    count := StrToInt(GetEditValue(ElementByIndex(componentAndCount, 1)));
    if (count > 90000) then count := count - 100000;
    
    gnam := getElementEditValues(linksTo(elementByIndex(componentAndCount, 0)), 'GNAM');

    if containsText(gnam, 'SuperCommon') OR containsText(gnam, 'Full') then begin
       count := count / 4;
    end
    else if containsText(gnam, 'Uncommon') OR containsText(gnam, 'None') then begin 
      count := count / 4;
    end
    else if containsText(gnam, 'Rare') then begin //rare, or other
      count := count / 2
    end;
    
    if (count > 4) then setEditValue(ElementByIndex(componentAndCount, 1), count)
    else removeElement(components, i);
  end;
  
  addMessage('FinishedProcessing');
  CleanMasters(patch);
  SortMasters(patch);
  endUpdate(cobj);
end;

  
//============================================================================  

function Process(e: IInterface): integer;
var
  conditions, condition, ctda, refCobj: IInterface;
  i, j: integer;
  isVanillaMaster : boolean ;
begin
    //NOTE - this is a workaround to get it to modify the parent file instead of creating a patch
    //patch := getFile(e);

    settlement := getFileName(getfile(masterOrSelf(e)));
    settlement := StringReplace(settlement, ' ', '', [rfReplaceAll, rfIgnoreCase]);
    settlement := StringReplace(settlement, '.esp', '', [rfReplaceAll, rfIgnoreCase]);
    settlement := StringReplace(settlement, '.esm', '', [rfReplaceAll, rfIgnoreCase]);
    settlement := StringReplace(settlement, '.esl', '', [rfReplaceAll, rfIgnoreCase]);
    
    isVanillaMaster := isMaster(e);

    //If it's from vanilla, but not disabled, then we need to leave it alone
    if not isMaster(e) AND not GetIsInitiallyDisabled(e) AND not getIsDeleted(e) AND not (Signature(e) = 'CELL') then begin
      addMessage('Found non-master REFR, ignoring ' + IntToHex(GetLoadOrderFormID(e), 8));
      exit;
    end;
    
    AddRequiredElementMasters(e, patch, false);
    if getIsDeleted(e) then begin
      addMessage('WARNING - FOUND DELETED RECORD');
      e := CopyToPatch(MasterOrSelf(e)); 
      setIsInitiallyDisabled(e, true);
    end else e := CopyToPatch(WinningOverride(e));
    
    //if shop, then disable
    if isShop(e) then begin
      setIsInitiallyDisabled(e, true);
      addMessage('Disabled shop ' + editorId(linksTo(ElementByPath(e, 'NAME'))));
      exit;
    end;

    //Disable workbenches
    if HasKeyword(linksTo(ElementByPath(e, 'NAME')), 'Workbench_General') AND isVanillaMaster then begin
      setIsInitiallyDisabled(e, true);
      addMessage('Disabled workbench ' + editorId(linksTo(ElementByPath(e, 'NAME'))));
      exit;
    end;

    if (Signature(e) = 'REFR') then begin
      
      if not initDone then begin
        init(e);
      end;

      //- add enabled parent, and set initially disabled
      Add(e, 'XESP', true);
      setElementEditValues(e, 'XESP\Reference', IntToHex(GetLoadOrderFormID(xmarker), 8));
      if GetIsInitiallyDisabled(e) then begin
        setElementEditValues(e, 'XESP\Flags\Set Enable State to Opposite of Parent', 1);
        setIsInitiallyDisabled(e, false);
        refCobj := getCobj(e);
        if assigned(refCobJ) then parseRecipe(refCobJ, true);
      end else begin
        setIsInitiallyDisabled(e, true);
        refCobj := getCobj(e);
        if assigned(refCobJ) then parseRecipe(refCobJ, false);

        //if container, then swap for empty
        swapRef(e);
      end;
    
      

    end 
    else if (Signature(e) = 'ACHR') then begin      
      //parse actors
      if GetIsInitiallyDisabled(e) then begin //renovate mods clear dead actors
        Add(e, 'XESP', true);
        setElementEditValues(e, 'XESP\Reference', IntToHex(GetLoadOrderFormID(xmarker), 8));
        setElementEditValues(e, 'XESP\Flags\Set Enable State to Opposite of Parent', 1);
        setIsInitiallyDisabled(e, false);
      end else begin
        setIsInitiallyDisabled(e, true);
        addMessage('Disabled actor ' + editorId(linksTo(ElementByPath(e, 'NAME'))));
      end;
    end else if (Signature(e) = 'CELL') and NOT getIsPersistent(e) then begin
      //Add cell to crafting conditions
      conditions := ElementByName(cobj, 'Conditions');
      if not Assigned(conditions) then begin
        conditions := Add(cobj, 'Conditions', true);
        condition := ElementByIndex(conditions, 0);
      end else condition  := ElementAssign(conditions, HighInteger, nil, true);

      ctda := ElementBySignature(ElementByIndex(conditions, ElementCount(conditions)-1), 'CTDA');
      SetEditValue(ElementByName(ctda, 'Type'), '10010000');
      SetNativeValue(ElementByName(ctda, 'Comparison Value - Float'), 1.0);
      SetEditValue(ElementByName(ctda, 'Function'), 'GetInCell');
      SetEditValue(ElementByName(ctda, 'CELL'), IntToHex(GetLoadOrderFormID(e), 8));
    
    end;
  

      
end;
//============================================================================  

// create and initialize new patch plugin
function CreatePatchPlugin: IInterface;
var
  header: IInterface;
begin
  Result := AddNewFile();

  if not Assigned(Result) then
    Exit;
	
  // set plugin's author and description
  header := ElementByIndex(Result, 0);
  Add(header, 'CNAM', True);
  SetElementEditValues(header, 'CNAM', sPatchAuthor);
end;  


//============================================================================
// copy record into a patch plugin
function CopyToPatch(r: IInterface): IInterface;
var
  rec: IInterface;
begin
    AddRequiredElementMasters(r, patch, false);
    rec := wbCopyElementToFile(r, patch, False, True);
    Result := rec;
end;


//============================================================================
function init(e: IInterface): IInterface;
var
  script, scriptProperty: IInterface;

begin
 
  //copy as new, assign xmarker as name, make sure it's not disabled
  xmarker := wbCopyElementToFile(e, patch, true, true);
  setElementEditValues(xmarker, 'NAME', '0000003B');
  SetIsInitiallyDisabled(xmarker, true);
  SetIsPersistent(xmarker, false);
  removeElement(xmarker, 'VMAD');
  //Create - Activator, assign script, fill scriptProperty
  acti := MainRecordByEditorID(GroupBySignature(masterFile, 'ACTI'), 'template_SettlementSupplies');
  acti := wbCopyElementToFile(acti, patch, true, true);
  setIsInitiallyDisabled(acti, true);
  setElementEditValues(acti, 'EDID', settlement + '_SettlementSupplies');
  script := elementByIndex(elementByPath(acti, 'VMAD\Scripts'), 0);
  setElementEditValues(script, 'ScriptName', 'SettlementAutoBuildSupplies');
  scriptProperty := elementByIndex(elementByPath(script, 'Properties'), 0);
  setElementEditValues(scriptProperty, 'propertyName', 'EnableParentRef');
  setElementEditValues(scriptProperty, 'Value\Object Union\Object v2\FormID', IntToHex(GetLoadOrderFormID(xmarker), 8));
  //Create - COBJ, assign activator, assign cmpos
  cobj := MainRecordByEditorID(GroupBySignature(masterFile, 'COBJ'), 'co_workshop_SettlementPlan_Template');
  AddRequiredElementMasters(cobj, patch, false);
  cobj := wbCopyElementToFile(cobj, patch, true, true);
  if not assigned(cobj) then raise Exception.Create('**ERROR** failed to cobj - Is the template override plugin loaded?');
  beginUpdate(cobj);

  setElementEditValues(cobj, 'EDID', 'workshop_co_' + settlement);
  setElementEditValues(cobj, 'CNAM', IntToHex(GetLoadOrderFormID(acti), 8));
  initDone := true;
	
end;
//============================================================================

function swapRef(e: IInterface): boolean;
var
  base, replacement: IINterface;
  
begin
  base := linksTo(ElementByPath(e, 'NAME'));
  if (signature(base) = 'CONT') then begin
    replacement := MainRecordByEditorID(GroupBySignature(masterFile, 'CONT'), editorId(base)+'_empty');
    if not assigned(replacement) then begin
      replacement := wbCopyElementToFile(base, patch, true, true);
      setElementEditValues(replacement, 'EDID', editorId(replacement)+'_empty');
      addMessage('Created a new non-base container record');
    end;
    setElementEditValues(e, 'NAME', IntToHex(GetLoadOrderFormID(replacement), 8));
  end;

end;

//============================================================================

function isShop(e: IInterface): boolean;
var
  i, j: integer;
  base, properties: IINterface;
  propav : String;
  
begin
  properties := elementByPath(linksTo(ElementByPath(e, 'NAME')), 'PRPS');
  for i := 0 to ElementCount(properties)-1 do begin
    propav := getElementEditValues(elementByIndex(properties, i), 'Actor Value');
    if containsText(propav, 'vendorIncome') then result := true;
    exit;
  end;
  result := false;
end;
//============================================================================

function getCobj(e: IInterface): IInterface;
var
  i, j: integer;
  base, ref, listRef: IINterface;
  
begin
  base := linksTo(ElementByPath(e, 'NAME'));
  for i := 0 to ReferencedByCount(base)-1 do begin
    ref := ReferencedByIndex(base, i);
    if (signature(ref) = 'COBJ') then begin 
      result := WinningOverride(ref);
      exit;
    end
    else if (signature(ref) = 'FLST') then for j := 0 to ReferencedByCount(ref)-1 do begin
      listRef := winningOverride(ReferencedByIndex(ref, j));
      if (signature(listRef) = 'COBJ') then begin
        result := WinningOverride(listRef);
        exit;
      end;
    end;
  end;
  addMessage('No scrap/crafting recipe found: ' + EditorId(base));

end;
//============================================================================

function parseRecipe(itemCobj: IInterface; isScrapped: boolean): boolean;
var
  i, j, count: integer;
  compFormId : string;
  recipeComponents, itemComponents, itemComponentAndCount, component: IINterface;
  isScrapRecipe: boolean;
  
begin
  
  //addMessage('Adding recipe components for ' + editorId(itemCobj));
  
  itemComponents := ElementByPath(itemCobj, 'FVPA - Components');
  recipeComponents := ElementByPath(cobj, 'FVPA - Components');
  isScrapRecipe := ContainsText(getEditValue(elementByIndex(elementByPath(itemCobj, 'FNAM'), 0)), 'WorkshopRecipeFilterScrap');
  for i := 0 to ElementCount(itemComponents)-1 do begin
    itemComponentAndCount := ElementByIndex(itemComponents, i);
    //addMessage('     Looking for : ' + GetEditValue(ElementByIndex(itemComponentAndCount, 0)));
    
    component := linksTo(ElementByIndex(itemComponentAndCount, 0));
    if (signature(component) = 'MISC') then component := LinksTo(ElementByIndex(ElementByIndex(ElementByPath(component, 'CVPA'), 0), 0));

    compFormId := intToHex(GetLoadOrderFormID(component), 8);
    count := GetEditValue(ElementByIndex(itemComponentAndCount, 1));
    if isScrapped then count := count * -1;
    if isScrapRecipe then count := count * 2;

    AddRequiredElementMasters(component, patch, false);
    addComponentToRecipe(compFormId, count);
  end;	
end;

//============================================================================
function addComponentToRecipe(addComponent: String; addCount: Integer): boolean;
var
  j, recipeCount: integer;
  recipeComponents, recipeComponentAndCount: IINterface;
  recipeComponent: string;
begin
  recipeComponents := ElementByPath(cobj, 'FVPA - Components');

  for j := ElementCount(recipeComponents)-1 downto 0 do begin
    recipeComponentAndCount := ElementByIndex(recipeComponents, j);
    recipeComponent := intToHex(GetLoadOrderFormID(linksTo(ElementByIndex(recipeComponentAndCount, 0))), 8);
    
    recipeCount := StrToInt(GetEditValue(ElementByIndex(recipeComponentAndCount, 1)));

    if (recipeComponent = addComponent) then begin
      setEditValue(ElementByIndex(recipeComponentAndCount, 1), recipeCount + addCount);
      //addMessage('          Adding: ' + IntToStr(addCount));
      exit;
    end;
  end;

  recipeComponentAndCount := ElementAssign(recipeComponents, HighInteger, nil, true);
  setEditValue(ElementByIndex(recipeComponentAndCount, 0), addComponent);
  setEditValue(ElementByIndex(recipeComponentAndCount, 1), addCount + 100000);
  //addMessage('          Not found, adding new : ' + IntToStr(addCount));

end;

end.
