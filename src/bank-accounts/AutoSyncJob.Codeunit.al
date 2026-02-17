codeunit 50112 "Chiizu Auto-Sync Job"
{
    trigger OnRun()
    var
        BankAcc: Record "Bank Account";
        BankAccRecon: Record "Bank Acc. Reconciliation";
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
    begin
        // 1. Filter for accounts that have been linked to Chiizu
        BankAcc.SetFilter("Chiizu Remote Balance", '>=%1', 0);
        if BankAcc.IsEmpty() then exit;

        if BankAcc.FindSet() then
            repeat
                // 2. Update the Balance field on the Bank Account card
                SetupMgmt.UpdateRemoteBalance(BankAcc);

                // 3. Find or Create an active Reconciliation Header
                BankAccRecon.SetRange("Bank Account No.", BankAcc."No.");
                BankAccRecon.SetRange("Statement Type", BankAccRecon."Statement Type"::"Bank Reconciliation");
                if not BankAccRecon.FindFirst() then begin
                    BankAccRecon.Init();
                    BankAccRecon."Statement Type" := BankAccRecon."Statement Type"::"Bank Reconciliation";
                    BankAccRecon."Bank Account No." := BankAcc."No.";
                    // Use IncStr to properly increment numeric strings (e.g., "10" becomes "11")
                    BankAccRecon."Statement No." := IncStr(BankAcc."Last Statement No.");
                    if BankAccRecon."Statement No." = '' then BankAccRecon."Statement No." := '1';
                    BankAccRecon.Insert();
                end;

                // 4. Import new transactions into the lines
                SetupMgmt.ImportToBankReconciliation(BankAccRecon);

                // 5. Run Auto-Match
                // We use Commit because Codeunit.Run is not allowed in a write transaction
                Commit();
                if not Codeunit.Run(Codeunit::"Match Bank Rec. Lines", BankAccRecon) then;

            until BankAcc.Next() = 0;

        // 6. Log completion status in Setup
        if Setup.Get('SETUP') then begin
            Setup."Last Sync Status" := 'Success';
            Setup."Last Sync Time" := CurrentDateTime();
            Setup.Modify();
        end;
    end;
}