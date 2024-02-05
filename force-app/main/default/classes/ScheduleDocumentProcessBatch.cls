/*
    Class Name : ScheduleDocumentProcessBatch
    Description : This is a class which implements a schedulable process which calls ProcessDocumentsBatch class
    Test Class : DocumentProcessingTest
    Cron expression on 05.02.2024 : '0 0 9/12 1/1 * ? *'

*/
global class ScheduleDocumentProcessBatch implements Schedulable {
    
    global void execute(SchedulableContext SC) {
       ProcessDocumentsBatch batchProcess = new ProcessDocumentsBatch(); 
       Database.executeBatch(batchProcess,200) ;
    }
}
