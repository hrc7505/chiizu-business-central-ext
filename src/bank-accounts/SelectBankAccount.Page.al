page 50106 "Chiizu Select Bank Account"
{
    PageType = StandardDialog;
    ApplicationArea = All;
    Caption = 'Select Bank Account';

    layout
    {
        area(content)
        {
            group(BankSelection)
            {
                Caption = 'Bank Account to Use';

                field(BankAccountNo; SelectedBankAccountNo)
                {
                    Caption = 'Bank Account';
                    ApplicationArea = All;
                    TableRelation = "Bank Account"."No.";
                }
            }
        }
    }

    var
        SelectedBankAccountNo: Code[20];
        WasConfirmed: Boolean;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = Action::OK then begin
            if SelectedBankAccountNo = '' then
                Error('Please select a bank account.');

            WasConfirmed := true;
        end;

        exit(true);
    end;

    procedure IsConfirmed(): Boolean
    begin
        exit(WasConfirmed);
    end;

    procedure GetSelectedBankAccount(): Code[20]
    begin
        exit(SelectedBankAccountNo);
    end;
}
