1. i want you to ALWAYS run ./!runme.cmd (which does dotnet watch run) in a **background terminal** so you monitor the output for build errors AND WARNINGS... if the c# project terminates, after fixing issues, start !runme.cmd again and keep monitoring it
2. dimension rules:
   1. height and width specified in config.yml represents the OUTER boundary of main window in default mode of hidden chrome
   2. calculate panel width and heights to fully fill the resulting main window client space
   3. taking into account the chrome of the panels is part of filling that space, not the client area of the panels but the outer panel form dimensions
   4. **without overflow** - observe the mainwindow and confirm that no scrollbars are present to claim victory
   5. at the end of output, display resulting main window client inner height and width AFTER toolbar height subtracted, also output total width and height of all panels combined and then compare the main window client dimensions to the panel totals and confirm they are correct
3. child panels must remain full MDI, not borderless
4. do not pause and ask confirmation unless there is something you need to ask me about that isn't covered in the above rules