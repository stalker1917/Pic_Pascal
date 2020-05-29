uses usercode;
uses piclibrary in '../API/piclibrary.pas';
begin
  Cpu := PIC18F4520; //Модель СPU
  Quartz := 8;  //Частота кварца в МГц,INTERAL -внутренний.
  YesCompile := True; //Компилируем C- программу
  RealTime   := True; //Такие же времена ,как на контроллере. 
  SetAsIn(RF);
  SetAsIn(RA+2); //Установить порт RA2 как входной.
  SetAsIn(RA+5);
  //SetTimer(1,9,nil);
  InitCPU; 
  SetTimer(1,5000000,OnTimer1);
  SetTimer(2,3000*Millisecond,OnTimer2);
  Run(Start);
end.