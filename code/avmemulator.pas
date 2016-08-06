{
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>
}

program AVM;
type
  uint8  = Byte;
  uint16 = Word;
   int16 = SmallInt;
  uint32 = Longword;
   int32 = LongInt;
const
  FILE_NOT_FOUND = 2;
var
  vmem : Array[0..99] of int32;
  vck, vckdef, vpk : uint16;
  va, vadef : int32;
  looplimit : uint32;
  tracemode : boolean;
  cmd : char;
  filename : string;
{#var}

function ParseCode( const filename : string ) : boolean;
var
  inputfile : Text;
  addr : int16;
begin
  {NOTE(adm244): 'i' switch disables IO checking,
  so we won't fail if Reset() executes with an error}
  
  Assign(inputfile, filename);
  {$i-}
  Reset(inputfile);
  {$i+}
  
  ParseCode := true;
  if IOResult = FILE_NOT_FOUND then begin
    WriteLn('ERROR: File with a program was not found!');
    WriteLn;
    ParseCode := false;
  end else begin
    while not EOF(inputfile) do begin
      Read(inputfile, addr);
      if (addr < 0) or (addr > 99) then begin
        Write('ERROR: Address [', addr, '] is outside memory boundaries! ');
        WriteLn('(Should be 0..99)');
        WriteLn;
        
        ParseCode := false;
        Break;
      end;
      Read(inputfile, vmem[addr]);
    end;
    
    Close(inputfile);
  end;
end;

{ AVM EMULATION }
procedure avmDivide( const addr : uint16 ); inline;
begin
  if vmem[addr] = 0 then begin
    Write('ERROR 20: Division by zero at [',vck,':',vpk,']. ');
    WriteLn('A = ', va, ', [',addr,'] = 0');
    Halt(20);
  end;
  
  va := va div vmem[addr];
end;

procedure avmRead( const addr : uint16 ); inline;
var
  temp : String;
  value : int32;
  err : uint16;
begin
  while true do begin
    Write('Enter a value to [',addr,']: ');
    ReadLn(temp);
  
    Val(temp, value, err);
    if err = 0 then begin
      vmem[addr] := value;
      Break;
    end else begin
      if (temp = 'c') then Halt
      else WriteLn('ERROR: Invalid value specified!');
    end;
  end;
end;

procedure avmOutput( const addr : uint16 ); inline;
begin
  if tracemode then begin
    Write('Output from [',addr,']: ', vmem[addr]);
    {NOTE(adm244): lookup Read() function implementation
     I suspect it's really messed up}
    //Read(cmd);
    ReadLn;
  end else WriteLn('Output from [',addr,']: ', vmem[addr]);
end;

procedure avmJump( const addr : uint16; var jumped : boolean ); inline;
begin
  vck := addr;
  jumped := true;
end;

procedure WriteValue( const addr : uint16 ); inline;
begin
  if addr > 10 then WriteLn(addr, ' = ', vmem[addr])
  else WriteLn('0', addr, ' = ', vmem[addr]);
end;

procedure RunAVM;
var
  code, addr : uint16;
  loop : uint32;
  jumped : boolean;
begin
  vck := vckdef;
  va := vadef;
  
  loop := 0;
  while true do begin
    if loop > looplimit then begin
      WriteLn;
      WriteLn('ERROR: Possible infinite loop detected!');
      WriteLn;
      Exit;
    end;
    
    jumped := false;
    vpk := vmem[vck];
    
    code := vpk div 100;
    addr := vpk mod 100;
    
    if tracemode then begin
      WriteLn;
      
      if vck < 10 then WriteLn('CK = 0', vck)
      else WriteLn('CK = ', vck);
      
      if vpk < 999 then Write('PK = 0', vpk)
      else Write('PK = ', vpk);
      case code of
        00: WriteLn(' [STOP]');
        01: begin
          WriteLn(' [LOAD A]');
          WriteValue(addr);
        end;
        02: WriteLn(' [SAVE A]');
        03: begin
          WriteLn(' [ADD TO A]');
          WriteValue(addr);
        end;
        04: begin
          WriteLn(' [SUB FROM A]');
          WriteValue(addr);
        end;
        05: begin
          WriteLn(' [MUL A]');
          WriteValue(addr);
        end;
        06: begin
          WriteLn(' [DIV A]');
          WriteValue(addr);
        end;
        07: WriteLn(' [INPUT]');
        08: WriteLn(' [OUTPUT]');
        09: WriteLn(' [JUMP]');
        10: WriteLn(' [JUMP IF A>0]');
        11: WriteLn(' [JUMP IF A=0]');
      end;
      
      WriteLn(' A = ', va);
      
      if not( (code = 07) or (code = 08) ) then begin
        Write('>');
        cmd := #0;
        ReadLn(cmd);
        case cmd of
          'q': Break;
          'c': Halt(0);
        end;
      end;
    end;
    
    case code of
      00: Break;
      01: va := vmem[addr];
      02: vmem[addr] := va;
      03: va := va + vmem[addr];
      04: va := va - vmem[addr];
      05: va := va * vmem[addr];
      06: avmDivide(addr);
      07: avmRead(addr);
      08: avmOutput(addr);
      09: avmJump(addr, jumped);
      10: if va > 0 then avmJump(addr, jumped);
      11: if va = 0 then avmJump(addr, jumped);
    end;
    
    if not jumped then
      vck := vck + 1;
    loop := loop + 1;
  end;
  
  WriteLn;
  WriteLn('Done!');
  WriteLn;
end;
{ #AVM EMULATION }

{ CONFIG LOADER }
function IsEmpty( const line : string ) : boolean;
var
  sympos : uint8;
begin
  IsEmpty := true;
  for sympos := 1 to Length(line) do begin
    if line[sympos] <> ' ' then begin
      IsEmpty := false;
      Break;
    end;
  end;
end;

function IsValid( const line : string ) : boolean;
var
  symbol : uint8;
begin
  IsValid := true;
  for symbol := 1 to Length(line) do begin
    if line[symbol] <> ' ' then begin
      if line[symbol] = ';' then begin
        IsValid := false;
        Break;
      end;
    end else Break;
  end;
end;

procedure DeleteSpaces( var line : string ); inline;
var
  sympos : uint8;
begin
  for sympos := 1 to Length(line) do begin
    if line[sympos] = ' ' then Delete(line, sympos, 1);
  end;
end;

procedure LoadConfig;
const
  CONST_FILENAME = 'program.txt';
  CONST_VCK = 10;
  CONST_VA = 0;
  CONST_LOOPLIMIT = 1000;
var
  inputfile : Text;
  line, param, value : String;
  sympos : uint8;
  errorcode : uint16;
begin
  filename := CONST_FILENAME;
  vck := CONST_VCK;
  va := CONST_VA;
  looplimit := CONST_LOOPLIMIT;
  
  Assign(inputfile, 'config');
  {$i-}
  Reset(inputfile);
  {$i+}
  
  if IOResult = FILE_NOT_FOUND then begin
    Rewrite(inputfile);
    
    WriteLn(inputfile, ';text file with a program');
    WriteLn(inputfile, 'filename = program.txt');
    WriteLn(inputfile);
    WriteLn(inputfile, ';starting address');
    WriteLn(inputfile, 'ck = 10');
    WriteLn(inputfile);
    WriteLn(inputfile, ';initial value in A register');
    WriteLn(inputfile, 'a = 0');
    WriteLn(inputfile);
    WriteLn(inputfile, ';a limit on processor ticks');
    WriteLn(inputfile, 'looplimit = 1000');
  end else begin
    while not EOF(inputfile) do begin
      ReadLn(inputfile, line);
      
      if IsValid(line) then begin
        line := Lowercase(line);
        DeleteSpaces(line);
        
        sympos := Pos('=', line);
        if sympos > 0 then begin
          param := Copy(line, 1, sympos-1);
          value := Copy(line, sympos+1, Length(line)-sympos);
          
          case param of
            'filename': if not IsEmpty(value) then filename := value;
            'ck': begin
              Val(value, vck, errorcode);
              if errorcode <> 0 then vck := CONST_VCK;
              if vck > 99 then vck := CONST_VCK;
            end;
            'a': begin
              Val(value, va, errorcode);
              if errorcode <> 0 then va := CONST_VA;
            end;
            'looplimit': begin
              Val(value, looplimit, errorcode);
              if errorcode <> 0 then looplimit := CONST_LOOPLIMIT;
            end;
          end; {#case}
        end;
      end;
    end; {#while}
  end;
  
  vckdef := vck;
  vadef := va;
  
  Close(inputfile);
end;
{ #CONFIG LOADER }

{ MAIN PROGRAM }
begin
  LoadConfig;
  
  while true do begin
    WriteLn('Abstract Virtual Machine');
    WriteLn(' r) Run program');
    WriteLn(' t) Run in trace mode');
    WriteLn(' c) Reload config file');
    WriteLn(' q) Quit');
    Write('>');
    ReadLn(cmd);
    
    case cmd of
      'q': Break;
      'r': begin
        tracemode := false;
        if ParseCode(filename) then RunAVM;
      end;
      't': begin
        tracemode := true;
        if ParseCode(filename) then RunAVM;
      end;
      'c': begin
        LoadConfig;
        WriteLn;
        WriteLn('Done!'); WriteLn;
      end
      else WriteLn;
    end;
  end;
end.
{ #MAIN PROGRAM }
