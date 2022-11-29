({
    doRegist : function(component, event, helper) {
    
    component.set("v.isProgress", true);
    
    const account2Freee = component.get("c.account2Freee");
    account2Freee.setParams({
    "accountId": component.get("v.recordId")
    });
    
    account2Freee.setCallback(this, (res) => {
    try {
    const state = res.getState();
    if (state === "SUCCESS") {
    
    component.set("v.isDone", true);
    }
    else {
    let message = 'エラーが発生しました\n';
    console.log(res.getError());
    message += res.getError()[0].message;
    component.set("v.errorMessage", message);
    component.set("v.isError", true);
    }
    } finally {
    component.set("v.isProgress", false);
    }
    });
    
    $A.enqueueAction(account2Freee);
    }
    })