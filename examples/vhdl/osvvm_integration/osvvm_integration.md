# OSVVM Integration
## Introduction
OSVVM is commonly used for its randomization and functional coverage features and is redistributed with VUnit as a convenience for our users. Having OSVVM in the VUnit repository means that the latest version is only a git pull away and we also simplified the inclusion of OSVVM in a project with a dedicated method in the VUnit user interface

```python
ui.add_osvvm()
```

Before OSVVM 2015.01 there were no integration issues when used with VUnit because the tools focused on different areas of testing. However, starting with version 2015.01 OSVVM also includes functionality for logging and checking (called alert in OSVVM) which raises some issues. VUnit strives to have a complete solution for logging and checking, covering most use cases, but when applying VUnit to legacy, already self-checking code, the most value comes from applying higher levels of VUnit automation rather than replacing old logging/checking mechanisms with those provided by VUnit. Because of this VUnit has the ability to integrate with other solutions like OSVVM.

[examples/osvvm\_integration](.) contains two testbenches [tb\_AlertLog\_Demo_Global](src/tb_AlertLog_Demo_Global.vhd) and [tb\_AlertLog\_Demo\_Hierarchy](src/tb_AlertLog_Demo_Hierarchy.vhd) that show how the two demo testbenches shipped with OSVVM 2015.01 can be transformed into VUnit testbenches while still keeping the original logging and checking mechanisms. The step-by-step transformation is done through a series of commits that start with the original code.

There are also two files [tb\_AlertLog\_Demo_Global\_With\_Comments](src/tb_AlertLog_Demo_Global_With_Comments.vhd) and [tb\_AlertLog\_Demo\_Hierarchy\_With\_Comments](src/tb_AlertLog_Demo_Hierarchy_With_Comments.vhd) that show how the OSVVM functionality is done in VUnit and also comment on the differences between the tools.

## The Role of Logging in Unit Testing
The VUnit logging package strives to support the most commonly used features when used as a standalone package. However, it's worth noting that logging isn't a first class activity in unit testing and advanced usage is rarely needed. The reason is that the test runner and the check procedures/functions provide much of the log organisation and verbosity control for free. For example

- The test runner organises information according to which test case it's related, i.e. the functionality being verified.
- The test runner and checks implement verbosity control by providing minimal information when test cases pass and if they fail they provide information on what check that failed, what the time is, and where it's located. This is often sufficient to handle debugging considering the limited size of units and the limited focus of a single test case

Sometimes extra logs are useful for debugging but such information is not interesting as long as test cases pass. This means that you should suppress debug logs for the display to avoid being overloaded with useless information and to avoid missing the more interesting progress information, warning and errors. If you have a failing test case then you want __all__ debug information since you can't know in advanced what will be interesting. This means that logs should be stored on file without any filtering. The risk of saving everything is that it may be hard to locate the interesting pieces of information. However, if you store the logs on a CSV format it can be imported into your spreadsheet tool which will provide much more filtering support than you would ever have from the verbosity control provided by your VHDL logging package. VUnit also provide [vunit/csv\_logs.py](../..vunit/csv_logs.py) which can merge and sort several CSV files into a single one before you open the spreadsheet tool.
