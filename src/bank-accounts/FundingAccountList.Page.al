page 50109 "Chiizu Funding Account List"
{
    PageType = List;
    SourceTable = "Chiizu Funding Account";
    SourceTableTemporary = true;
    Caption = 'Select Chiizu Funding Accounts';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Status; GetImportStatus())
                {
                    ApplicationArea = All;
                    Caption = 'Import Status';
                    StyleExpr = StatusStyle; // Optional: Makes "Linked" green
                }
                field(Name; Rec.Name) { ApplicationArea = All; }
                field("Account Number"; Rec."Account Number") { ApplicationArea = All; }
                field("Account Type"; Rec."Account Type") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
            }
        }
    }

    var
        StatusStyle: Text;

    local procedure GetImportStatus(): Text
    var
        BankAcc: Record "Bank Account";
    begin
        if BankAcc.Get(Rec."Account Id") then begin
            StatusStyle := 'Favorable'; // Green text
            exit('Already Linked');
        end;

        StatusStyle := 'None';
        exit('New');
    end;

    procedure SetAccounts(var TempAcc: Record "Chiizu Funding Account" temporary)
    var
        BankAcc: Record "Bank Account";
    begin
        Rec.Reset();
        Rec.DeleteAll();
        if TempAcc.FindSet() then
            repeat
                // 🔹 Only add to the view if it DOES NOT exist in BC
                if not BankAcc.Get(TempAcc."Account Id") then begin
                    Rec.Init();
                    Rec.Copy(TempAcc);
                    Rec.Insert();
                end;
            until TempAcc.Next() = 0;
    end;

    procedure GetSelectedRecords(var TempFundingAcc: Record "Chiizu Funding Account" temporary)
    begin
        TempFundingAcc.Reset();
        TempFundingAcc.DeleteAll();

        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindSet() then
            repeat
                TempFundingAcc.Init();
                TempFundingAcc.Copy(Rec);
                TempFundingAcc.Insert();
            until Rec.Next() = 0;
    end;
}