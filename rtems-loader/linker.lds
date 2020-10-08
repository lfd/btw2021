SECTIONS
{
	. = 0;
	.boot           : {
		*(.boot.entry)
		*(.boot)
	}

}

ENTRY(__reset_entry)
