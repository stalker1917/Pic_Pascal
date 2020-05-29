﻿unit PicLibrary;
interface
uses translator;
const 
  PIC18F4520 = 0;
 // PIC18F4520_Clock = 40;
  RA = 0;
  RB = 10;
  RC = 20;
  RD = 30;
  RE = 40;
  RF = 50; 
  INTERAL = 10000; //INTIO2; 
  Millisecond = 1000;
  
//const 
  //TRISA,TRISB,TRISC,TRISD,TRISE,TRISF : Byte = 0;  

 
var 
  Cpu         : Integer;
  Quartz      : Integer; //Mhz
  Clock       : Integer;
  YesCompile  : Boolean = False;
  RealTime    : Boolean = True;
  FMain       : Text;
  FInit       : Text;
  FSketch     : Text;
  InitCPUF    : Boolean = False; //Сработала ли инициализация CPU;
  RunF        : Boolean = False; //Сработала ли инициализация таймеров;
  TRIS        : Array [0..6] of Byte = (0,0,0,0,0,0,0);
  MainCode    : TText;

type  
TCallBackProc = procedure(var A:Array of byte;Count:Integer);
TInterrupt = procedure;

//TPICCOntroller = Array[0..2] of Byte; 
TPICCOntroller = record
  Clock : Integer;
  Timers,Uarts :Integer;
end;
  
//Частота, Количество таймеров,Количество UART            
var 
  PICControllers : TPICCOntroller = (Clock : 40; Timers:4; Uarts:1);
type  
TUART = record
  BaudRate    : SmallInt;
  TXReg,RxReg : Byte;
  OnRxChar    : TInterrupt;
  OnPCRxChar  : TCallBackProc;   
end; 

TTimer = record
   Counter : Int64;
   Delay   : Int64;
   Prescale : Byte;
   ProgramScale : Integer; 
   Tail : Integer; 
   PrescaleCode : Byte;
   //Cycles : Integer;
   IntProc : TInterrupt;
end;

var 
UARTs    :  Array of TUART;
Timers   :  Array of TTimer;
InitProc :  procedure;

procedure PrepareToMain;
procedure Run(P:procedure); //Применить установленную конфигурацию. 
procedure InitCPU; //Инициализация CPU
procedure SetTimer(N:Byte;Delayus:Int64;Interrupt:TInterrupt);//Инициализация USART
//Инициализация таймеров.  
procedure SetAsIn(Port:Byte); 
procedure SetBit(Port,Bit:Byte);

implementation
procedure InitCPU;
var S:String;
C:Char;
i:Integer;
  begin
    if initCPUF then 
      begin
        WriteLn('Ошибка: нельзя вызывать функцию InitCPU два раза!');
        exit;
      end;
    initCPUF := True;
    if YesCompile then
       begin
         Assign(FMain,'main.c');
         Rewrite(FMain);
         Assign(FInit,'init.c');
         Rewrite(FInit);
       end;  
    case Cpu of 
      PIC18F4520:
        begin
           if YesCompile then
             begin
          Assign(FSketch,'../Sketch/PIC18F4520_main.txt');
          Reset(FSketch);
          while (not Eof(FSketch)) do
            begin
              Readln(FSketch,S);
              WriteLn(FMain,S);
            end;
          close(FSketch);  
          Assign(FSketch,'../Sketch/PIC18F4520_init.txt');
          Reset(FSketch);
          while (not Eof(FSketch)) do
            begin
              Readln(FSketch,S);
              WriteLn(FInit,S);
            end;
          Close(FSketch); 
          end;  
          
         // Clock :=  PICControllers.Clock;//PIC18F4520_Clock;
          if Quartz>PICControllers.Clock then 
            begin
              WriteLn('Используем внутренний осцилятор.');
              if YesCompile then 
                begin
                WriteLn(FMain,'#pragma config OSC = INTIO2');
                WriteLn(FInit,'  OSCTUNE = 0b01000000; //8Mhz*4');
                Clock := 32;
                end;
            end  
          else 
            if Quartz>(PICControllers.Clock/4) then 
              begin
                Clock := Quartz;
                WriteLn('Используем внешний осцилятор частотой ',Quartz,' МГц. Режим HS.');
                if YesCompile then WriteLn(FMain,'#pragma config OSC = HS');
              end
            else 
              begin
                Clock := Quartz*4;
                WriteLn('Используем внешний осцилятор частотой ',Quartz,' МГц. Режим HSPLL.');
                if YesCompile then WriteLn(FMain,'#pragma config OSC = HSPLL');
              end;  
          WriteLn('Частота контроллера - ',Clock,' МГц.'); 
          if YesCompile then
            begin
          c := 'A';
          for i:=0 to 4 do
            begin
              WriteLn(FInit,'  TRIS',C,' = ',TRIS[I],';');
              WriteLn(FInit,'  LAT',C,' = 0;');
              inc(C);
            end;
           end;
        end;
    end;
//Стартовала пользовательская программа. 
  WriteLn(FInit,'}');
  if YesCompile then Flush(FMain);  
  if YesCompile then Flush(FInit);  
For i := 0 to High(Timers) do  Timers[i].Delay := 0;  //Таймеры выключены. 


  
end;
procedure SetTimer(N:Byte;Delayus:Int64;Interrupt:TInterrupt);
var FCycles : Double;
begin
  if (not InitCpuf) then 
    begin
      WriteLn('Нельзя инициализировать таймеры до инициализации контроллера');
      exit;
    end;
  if (Runf) then 
    begin
      WriteLn('Нельзя инициализировать таймеры из основной программы после запуска');
      exit;
    end;  
  if N>High(Timers) then WriteLn('Таймера ',N,' не существует для данного типа контроллеров')
  else 
    begin
      Timers[N].IntProc := Interrupt; 
      Timers[N].Delay := Delayus;
      Timers[N].Counter := Delayus;
      case Cpu of 
        PIC18F4520: 
          begin
            FCycles := (Clock*Delayus)/4;
            Timers[N].Prescalecode := 0; 
            Timers[N].Prescale := 1;
            //else 
              if N<>2 then
                while (FCycles>255) and (Timers[N].Prescale<8) do 
                  begin
                     Timers[N].Prescale := Timers[N].Prescale*2;
                     inc(Timers[N].Prescalecode);
                     FCycles := FCycles/2;
                  end
              else      
                while (FCycles>255) and (Timers[N].Prescale<16) do 
                   begin
                     Timers[N].Prescale := Timers[N].Prescale*4;
                     inc(Timers[N].Prescalecode);
                     FCycles := FCycles/4;
                   end;
            Timers[N].ProgramScale := Trunc(FCycles/256); //Сколько цикло по 255
            Timers[N].Tail := Round(FCycles) - Timers[N].ProgramScale*256; //Последний цикл обрезанный.
            WriteLn('Установлено срабатывание таймера №',N,' по истечению ',(Round(FCycles)*Timers[N].Prescale*4)/Clock,' мкс');
            //Prescale 1..8
          end;
      end;    
    end;
end; 

{
function BitToByte(B:Byte):Byte;
begin
  result shl(
end;
}

procedure SetAsIn(Port:Byte); 
var c:Char; i:Integer;
begin
  if initCPUF then WriteLn('Ошибка: нельзя задавать порт на вход после выполнения InitCPU!')
  else
    begin
      case Cpu of 
        PIC18F4520: 
          if Port>42 then 
             begin
               WriteLn('Ошибка: нет такого порта!');
               exit;
             end;
      end;
      C := 'A';
      For i:=0 to (Port div 10)-1 do inc(C);
      WriteLn('Порт R',C,Chr($30+Port mod 10),' успешно задан на вход');
      TRIS[Port div 10]:= TRIS[Port div 10] or (1 shl (Port mod 10)); 
    end;    
end;

Function TimerReset(i:Integer;ForceTail:Boolean):String;
var j:Integer;
begin
       if (Timers[i].ProgramScale>0) and (not ForceTail) then 
           if (i mod 2)=0 then Result := 'TMR'+IntToStr(i)+' = 0;'
                          else Result := 'TMR'+IntToStr(i)+' = 0xff00;'
        else
          begin
           if (i mod 2)=0 then j:=256-Timers[i].Tail
                          else j:=66526-Timers[i].Tail;
           if ForceTail then  Result := 'TMR'+IntToStr(i)+' = Timer'+IntToStr(i)+'_tail'+';'             
                        else Result := 'TMR'+IntToStr(i)+' = '+IntToStr(j)+';';               
          end;  
end;

procedure CompileInitTimers;
var S:String;
i,j:Integer;
begin
   case Cpu of 
      PIC18F4520:
           Assign(FSketch,'../Sketch/PIC18F4520_timers.txt');
   end;        
  Reset(FSketch);
  while (not Eof(FSketch)) do
    begin
      Readln(FSketch,S);
      WriteLn(FInit,S);
    end; 
  Close(FSketch);  
  For i := 0 to High(Timers) do 
    if Timers[i].Delay>0 then
      begin
        if i=0 then WriteLn(FInit,'T',i,'CONbits.T',i,'PS = ',Timers[i].PrescaleCode,';')
               else WriteLn(FInit,'T',i,'CONbits.T',i,'CKPS = ',Timers[i].PrescaleCode, ';'); 
        WriteLn(FInit,TimerReset(I,False));
        WriteLn(FInit,'T',i,'CONbits.TMR',i,'ON = 1;');   
        WriteLn(FInit,'');
      end;
  WriteLn(FInit,'}'); 
  WriteLn(FInit,'void InitUART(void)');
   WriteLn(FInit,''); 
  WriteLn(FInit,'{');
  WriteLn(FInit,'}');
  Flush(FInit);  
end;  

procedure SetBit;
var C:Char;
i:Integer;
begin
   C := 'A';
   For i:=0 to (Port div 10)-1 do inc(C);
   WriteLn('Порт R',C,Chr($30+Port mod 10),' успешно установлен на ',Bit);  
end;

procedure PrepareToMain;
var i:Integer;
begin
  for i:=0 to High(Timers) do 
    if Timers[i].Delay>0 then
       begin
         AddTText(MainCode,'int Timer'+IntToStr(i)+'_maxcount = '+IntToStr(Timers[i].ProgramScale)+';');
         AddTText(MainCode,'int Timer'+IntToStr(i)+'_tail = '+IntToStr(Timers[i].Tail)+';');
         AddTText(MainCode,'int Timer'+IntToStr(i)+'_counter = 0;');
       end;  
  AddTText(MainCode,'int main(int argc, char** argv);');
  AddTText(MainCode,'void __interrupt() high_isr(void);'); 
  AddTText(MainCode,'int main(int argc, char** argv)');
  AddTText(MainCode,'{');
  AddTText(MainCode,'  Init();');  
end;

procedure PrepareToHigh_isr;
begin
  AddTText(MainCode,'void __interrupt() high_isr(void)'); 
  AddTText(MainCode,'{');
end;

procedure PrepareTimer;
begin
  AddTText(MainCode,'void __interrupt() high_isr(void)'); 
  AddTText(MainCode,'{');
end;

procedure RunTimer(i:Integer);
begin
  case i of
    0:
      begin
      AddTText(MainCode,'if ((INTCONbits.TMR0IF) && ( INTCONbits.TMR0IE)) {'); 
      AddTText(MainCode,'INTCONbits.TMR0IF = 0;'); 
      end;
    1:
      begin
      AddTText(MainCode,'if ((PIE1bits.TMR1IE) && (PIR1bits.TMR1IF)) {'); 
      AddTText(MainCode,'PIR1bits.TMR1IF = 0;'); 
      end; 
    2:
      begin
      AddTText(MainCode,'if ((PIE1bits.TMR2IE) && (PIR1bits.TMR2IF)) {'); 
      AddTText(MainCode,'PIR1bits.TMR2IF = 0;'); 
      end; 
    3:
      begin
      AddTText(MainCode,'if ((PIE2bits.TMR3IE ) && (PIR2bits.TMR3IF)) {'); 
      AddTText(MainCode,'PIR2bits.TMR3IF = 0;');
      end; 
    end;  
    AddTText(MainCode,'Timer'+IntToStr(i)+'_counter++;'); 
    AddTText(MainCode,'if (Timer'+IntToStr(i)+'_counter <= Timer'+IntToStr(i)+'_maxcount)');
    AddTText(MainCode,'  if (Timer'+IntToStr(i)+'_counter == Timer'+IntToStr(i)+'_maxcount) '+TimerReset(i,True));
    AddTText(MainCode,'  else '+TimerReset(i,False));
    AddTText(MainCode,'else ');
    AddTText(MainCode,'{');
    AddTText(MainCode,'Timer'+IntToStr(i)+'_counter = 0;');
    AddTText(MainCode,TimerReset(i,False));
    AddTText(MainCode,'//User code'); 
end;

procedure Run;
var 
  i,mini:Integer;
  mincount : Int64;
begin
  if YesCompile then CompileInitTimers;
  RunF := True;
  if YesCompile then
  begin 
    FileToText('operators.txt',Operators);
    AddTText(Operators,' ');
    FileToText('usercode.pas',Code);
    SetLength(MainCode,0);
    CompileConst(MainCode);
    CompileVar(MainCode);
    PrepareToMain;
    CompileText(MainCode,'Start');
    AddTText(MainCode,'  while (1) {}');   //Суперцикл.  
    AddTText(MainCode,'  return (EXIT_SUCCESS);');
    AddTText(MainCode,'}');
    PrepareToHigh_isr;
    for i:=0 to High(Timers) do
      if Timers[i].Delay>0 then
        begin
          RunTimer(i);
          CompileText(MainCode,'OnTimer'+InttoStr(i));
          AddTText(MainCode,'}');
          AddTText(MainCode,'}');
        end;
    AddTText(MainCode,'}');
    For i:=0 to High(MainCode) do Writeln(FMain,MainCode[i]);
    Flush(FMain);
  end;
  
  InitProc := P;
  
  
  WriteLn('Запущена процедура Start');
  InitProc;
  while true do
    begin
      mini := -1;
      mincount := 1000000000;
      
      for i:= 0 to High(Timers) do 
        if (Timers[i].Counter<mincount) and (Timers[i].Delay>0) then
          begin
           mini := i;
           mincount := Timers[mini].Counter;
          end; 
      if (i=-1) then exit;// Таймеры выключены.
      for i:= 0 to High(Timers) do 
        if (Timers[i].Delay>0) then Timers[i].Counter -= mincount; 
      if Realtime then Sleep(Round(mincount/1000));
      WriteLn('Прошло ',mincount,' мкс.');
      Timers[mini].Counter := Timers[mini].Delay;
      Timers[mini].IntProc;
        
    end;
  //Инициализируем UART
  //Инициализируем Таймер
  //Суперцикл
end;    
  
begin
  SetLength(UARTs,PICControllers.Uarts);
  SetLength(Timers,PICControllers.Timers);
end.  
 
 