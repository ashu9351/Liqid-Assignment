/*
    Class Name : ScheduleDocumentProcessBatch
    Description : This is a class which implements a schedulable process which calls ProcessDocumentsBatch class
    Test Class : DocumentProcessingTest

*/
global class ScheduleDocumentProcessBatch implements Schedulable {
    
    global void execute(SchedulableContext SC) {
       ProcessDocumentsBatch batchProcess = new ProcessDocumentsBatch(); 
       Database.executeBatch(batchProcess,200) ;
    }
}
