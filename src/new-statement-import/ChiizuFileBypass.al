codeunit 50120 "Chiizu File Bypass"
{
    TableNo = "Data Exch."; // Must be Data Exch to prevent crashes!

    trigger OnRun()
    begin
        // Doing nothing here intentionally skips Microsoft's native "Choose File" popup.
        // It immediately hands control over to our Processing Codeunit below.
    end;
}