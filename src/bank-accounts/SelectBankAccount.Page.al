page 50106 "Chiizu Select Bank Account"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'Select Bank Account';

    layout
    {
        area(content)
        {
            group(BankSelection)
            {
                Caption = 'Bank Account to Use';
                field("Bank Account No."; SelectedBankAccountNo)
                {
                    TableRelation = "Bank Account"."No.";
                    ApplicationArea = All;
                    Caption = 'Bank Account';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(OK)
            {
                Caption = 'OK';
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        SelectedBankAccountNo: Code[20];

    procedure SetInvoices(InvoiceNos: List of [Code[20]])
    begin
        // Optional: store invoices to show summary
    end;

    procedure GetSelectedBankAccount(): Code[20]
    begin
        exit(SelectedBankAccountNo);
    end;
}
