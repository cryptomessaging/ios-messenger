BotWidgetHost = (function () {
    var my = {};
                 
    //===== Navigation =====
                 
    my.closeBotWidget = function() {
        window.webkit.messageHandlers.closeBotWidget.postMessage({});
    }
    
    //===== Config =====
                
    // set the object name used for callbacks from the Application
    my.setCallbackObjectName = function(objectName) {
        var msg = { name:objectName };
        window.webkit.messageHandlers.setCallbackObjectName.postMessage(msg);
    }
    my.setCallbackObjectName("BotWidgetCallbacks"); // default value
    
    // set desired height of bot widget
    my.setHeight = function(height) {
        var msg = { height:height };
        window.webkit.messageHandlers.setHeight.postMessage(msg);
    }
                 
    my.fetchEnvironment = function() {
        window.webkit.messageHandlers.fetchEnvironment.postMessage({});
    }
                
    my.setOptionItems = function(options) {
        window.webkit.messageHandlers.setOptionItems.postMessage(options);
    }
                 
    my.setBackButton = function(options) {
        window.webkit.messageHandlers.setBackButton.postMessage(options);
    }

    my.setupScreen = function(options) {
        window.webkit.messageHandlers.setupScreen.postMessage(options);
    }
                
    //===== Location =====
    
    // duration in seconds
    my.fetchLocation = function(duration) {
        window.webkit.messageHandlers.fetchLocation.postMessage({});
    }
    
    my.sendLocation = function(duration) {
        window.webkit.messageHandlers.sendLocation.postMessage({});
    }
    
    my.requestLocationUpdates = function(minutes) {
        var msg = { minutes: minutes };
        window.webkit.messageHandlers.requestLocationUpdates.postMessage(msg);
    }
    
    my.cancelLocationUpdates = function(duration) {
        window.webkit.messageHandlers.cancelLocationUpdates.postMessage({});
    }
    
    
    //===== Calendar =====
    
    // Default is two weeks from today
    my.fetchFreeBusy = function(startDay,endDay) {
        var msg = { startDay:startDay, endDay:endDay };
        window.webkit.messageHandlers.fetchFreeBusy.postMessage(msg);
    }
    
    // monitor free/busy and send offline updates to bot server
    my.requestFreeBusyUpdates = function(startDay,endDay,webhook) {
        var msg = { startDay:startDay, endDay:endDay, webhook:webhook };
        window.webkit.messageHandlers.requestFreeBusyUpdates.postMessage(msg);
    }
                 
    my.cancelFreeBusyUpdates = function() {
        window.webkit.messageHandlers.cancelFreeBusyUpdates.postMessage({});
    }
    
    //===== Thread/messages =====
    
    my.fetchThreadList = function(tids) {
        var msg = { tids: tids };
        window.webkit.messageHandlers.fetchThreadList.postMessage(msg);
    }
                 
    my.fetchThread = function() {
        window.webkit.messageHandlers.fetchThread.postMessage({});
    }
    
    my.fetchMessageHistory = function() {
        window.webkit.messageHandlers.fetchMessageHistory.postMessage({});
    }
                 
    my.ensureExclusiveChat = function(options) {
        window.webkit.messageHandlers.ensureExclusiveChat.postMessage(options);
    }
                 
    my.showChat = function(options) {
        window.webkit.messageHandlers.showChat.postMessage(options);
    }
                
    //===== Cards =====
    
    my.fetchThreadCards = function() {
        window.webkit.messageHandlers.fetchThreadCards.postMessage({});
    }
    
    my.fetchUserCard = function() {
        window.webkit.messageHandlers.fetchUserCard.postMessage({});
    }
    
    my.fetchBotCard = function() {
        window.webkit.messageHandlers.fetchBotCard.postMessage({});
    }
                 
    my.selectUserCard = function(options) {
        window.webkit.messageHandlers.selectUserCard.postMessage(options);
    }
    
    //===== RPC =====
                
    my.queryBotServerJson = function(handle,path) {
        var msg = { handle:handle, path:path };
        window.webkit.messageHandlers.queryBotServerJson.postMessage(msg);
    }
                
    my.updateBotServerJson = function(handle,method,path,data) {
        var json = JSON.stringify(data);
        my.updateBotServer(handle,method,path,json,"application/json");
    }
    
    my.updateBotServer = function(handle,method,path,content,contentType) {
        var msg = { handle:handle, method:method, path:path, content:content, contentType:contentType };
        window.webkit.messageHandlers.updateBotServer.postMessage(msg);
    }
    
    return my;
}());
