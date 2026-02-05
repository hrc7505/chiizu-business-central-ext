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
                    Caption = 'Bank Account No.';
                    ApplicationArea = All;
                    TableRelation = "Bank Account"."No.";

                    trigger OnValidate()
                    var
                        BankAcc: Record "Bank Account";
                    begin
                        // Refresh the Name whenever No. changes
                        Clear(SelectedBankAccountName);

                        if SelectedBankAccountNo <> '' then begin
                            if BankAcc.Get(SelectedBankAccountNo) then
                                SelectedBankAccountName := BankAcc.Name
                            else
                                Error('Bank account not found: %1', SelectedBankAccountNo);
                        end;
                    end;

                }
            }
        }
    }

    var
        SelectedBankAccountNo: Code[20];
        SelectedBankAccountName: Text[100];

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = Action::OK then begin
            if SelectedBankAccountNo = '' then
                Error('Please select a bank account.');
        end;

        exit(true);
    end;

    procedure GetSelectedBankAccountNo(): Code[20]
    begin
        exit(SelectedBankAccountNo);
    end;

    procedure GetSelectedBankAccountName(): Text[100]
    begin
        exit(SelectedBankAccountName);
    end;
}
