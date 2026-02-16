codeunit 50112 "Chiizu Auto-Sync Job"
{
    trigger OnRun()
    var
        BankAcc: Record "Bank Account";
        BankAccRecon: Record "Bank Acc. Reconciliation";
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        MatchBankRecLines: Codeunit "Match Bank Rec. Lines";
    begin
        // 1. Filter for Chiizu-linked accounts
        BankAcc.SetFilter("Chiizu Remote Balance", '>=%1', 0);
        if BankAcc.IsEmpty() then exit;

        if BankAcc.FindSet() then
            repeat
                SetupMgmt.UpdateRemoteBalance(BankAcc); // [cite: 15, 92]

                BankAccRecon.SetRange("Bank Account No.", BankAcc."No."); // [cite: 31, 93]
                if not BankAccRecon.FindFirst() then begin
                    BankAccRecon.Init();
                    BankAccRecon."Statement Type" := BankAccRecon."Statement Type"::"Bank Reconciliation";
                    BankAccRecon."Bank Account No." := BankAcc."No.";
                    BankAccRecon."Statement No." := BankAcc."Last Statement No." + '1';
                    BankAccRecon.Insert(); // [cite: 61, 70, 74]
                end;

                SetupMgmt.ImportToBankReconciliation(BankAccRecon); // [cite: 59, 98]

                // 🔹 SILENT AUTO-MATCH: This stops the multiple alert boxes 
                Commit(); // Necessary before Codeunit.Run inside a loop
                if not Codeunit.Run(Codeunit::"Match Bank Rec. Lines", BankAccRecon) then;

            until BankAcc.Next() = 0;

        // 6. Log results to Setup
        if Setup.Get('SETUP') then begin
            Setup."Last Sync Status" := 'Success';
            Setup."Last Sync Time" := CurrentDateTime();
            Setup."Auto-Sync Enabled" := true;
            Setup.Modify();
        end;
    end;
}