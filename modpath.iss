// modifypath -- removes any existing copy of {app} from the user PATH and
// re-adds it (idempotent). Runs at post-install when the modifypath task is
// selected. PascalScript-safe: no array-of-function-result indexing.

procedure ModPath();
var
  Paths: TStringList;
  PathOriginal: String;
  PathNew: String;
  Dir: String;
  i: Integer;
begin
  Dir := ExpandConstant('{app}');
  PathOriginal := '';
  RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', PathOriginal);

  Paths := TStringList.Create;
  try
    Paths.Delimiter := ';';
    Paths.DelimitedText := PathOriginal;
    for i := Paths.Count - 1 downto 0 do
    begin
      if CompareText(Paths[i], Dir) = 0 then
        Paths.Delete(i);
    end;
    Paths.Add(Dir);
    PathNew := '';
    for i := 0 to Paths.Count - 1 do
    begin
      if i > 0 then
        PathNew := PathNew + ';';
      PathNew := PathNew + Paths[i];
    end;
  finally
    Paths.Free;
  end;

  RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', PathNew);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if IsTaskSelected('modifypath') then
      ModPath();
  end;
end;
