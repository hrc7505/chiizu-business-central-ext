codeunit 50112 "Chiizu Auto-Sync Job"
{
    trigger OnRun()
    var
        BankAcc: Record "Bank Account";
        BankAccRecon: Record "Bank Acc. Reconciliation";
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        MatchBankRecLines: Codeunit "Match Bank Rec. Lines";
        Log: Record "Chiizu Sync Log";
        TargetStatementNo: Code[20];
    begin
        BankAcc.SetFilter("Chiizu Remote Balance", '>=%1', 0);
        if BankAcc.IsEmpty() then exit;

        if BankAcc.FindSet() then
            repeat
                SetupMgmt.UpdateRemoteBalance(BankAcc);

                TargetStatementNo := IncStr(BankAcc."Last Statement No.");
                if TargetStatementNo = '' then TargetStatementNo := '1';

                if not BankAccRecon.Get(BankAccRecon."Statement Type"::"Bank Reconciliation", BankAcc."No.", TargetStatementNo) then begin
                    BankAccRecon.Init();
                    BankAccRecon."Statement Type" := BankAccRecon."Statement Type"::"Bank Reconciliation";
                    BankAccRecon."Bank Account No." := BankAcc."No.";
                    BankAccRecon."Statement No." := TargetStatementNo;
                    BankAccRecon.Insert(true);
                end;

                SetupMgmt.ImportToBankReconciliation(BankAccRecon);

                Commit();
                MatchBankRecLines.BankAccReconciliationAutoMatch(BankAccRecon, 1);

                // Check if the statement is balanced
                if IsReconBalanced(BankAccRecon) then begin
                    // Balanced and ready for user
                end;

            until BankAcc.Next() = 0;

        if Setup.Get('SETUP') then begin
            Setup."Last Sync Status" := 'Success';
            Setup."Last Sync Time" := CurrentDateTime();
            Setup.Modify();
        end;
    end;

    local procedure IsReconBalanced(var BankAccRecon: Record "Bank Acc. Reconciliation"): Boolean
    var
        ReconLine: Record "Bank Acc. Reconciliation Line";
        TotalApplied: Decimal;
    begin
        // 🔹 FIX: Since "Difference" isn't on the table, we calculate it manually
        // Difference = Statement Ending Balance - (Balance Last Statement + Total Applied Amount)

        ReconLine.SetRange("Statement Type", BankAccRecon."Statement Type");
        ReconLine.SetRange("Bank Account No.", BankAccRecon."Bank Account No.");
        ReconLine.SetRange("Statement No.", BankAccRecon."Statement No.");

        if ReconLine.FindSet() then
            repeat
                TotalApplied += ReconLine."Applied Amount";
            until ReconLine.Next() = 0;

        // Returns true if the math equals zero
        exit(BankAccRecon."Statement Ending Balance" = (BankAccRecon."Balance Last Statement" + TotalApplied));
    end;
}