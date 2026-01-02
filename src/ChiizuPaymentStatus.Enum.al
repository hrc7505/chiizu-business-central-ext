enum 50111 "Chiizu Payment Status"
{
    Extensible = true;

    value(0; Open)
    {
        Caption = 'Open';
    }

    value(1; Scheduled)
    {
        Caption = 'Scheduled';
    }

    value(2; Processing)
    {
        Caption = 'Processing';
    }

    value(3; Paid)
    {
        Caption = 'Paid';
    }

    value(4; Cancelled)
    {
        Caption = 'Cancelled';
    }

    value(5; Failed)
    {
        Caption = 'Failed';
    }
}
