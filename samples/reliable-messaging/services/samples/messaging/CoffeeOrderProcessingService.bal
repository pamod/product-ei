package samples.messaging;

import ballerina.net.jms;
import ballerina.net.http;
import ballerina.runtime;

@Description{value:"Retreive the order message from the queue and reliably send it to downstream service"}
@jms:configuration {
    initialContextFactory:"wso2mbInitialContextFactory",
    providerUrl:"amqp://admin:admin@carbon/carbon?brokerlist='tcp://localhost:5672'",
    connectionFactoryName:"QueueConnectionFactory",
    concurrentConsumers:1,
    acknowledgementMode:jms:CLIENT_ACKNOWLEDGE,
    destination:"CoffeeOrders"
}
service<jms> coffeeConsumerService {

    endpoint<http:HttpClient> orderDispatchEp {
        create http:HttpClient("http://localhost:9091/dispatch", {});
    }

    resource onMessage (jms:JMSMessage m) {
        // Retrieve the order message obtained from the queue
        string orderMessage = m.getTextMessageContent();
        http:HttpConnectorError pizzaSendError;
        println("Payload: " + orderMessage + " received by processing service");
        //Create a http message based on the content specified in JMS message
        http:Request pizzaOrderRequest = {};
        pizzaOrderRequest.setJsonPayload(orderMessage);
        //Create a place holder to retrieve the response obtained from coffee order service
        http:Response pizzaResponse = {};
        //Dispatch the order message to the respective endpoint.
        pizzaResponse, pizzaSendError = orderDispatchEp.post("/coffeeOrder", pizzaOrderRequest);
        //Check if there's an error, if there's no error the message will be polled from the queue upon completion of
        //this operation
        if (pizzaSendError != null) {
            println("Error occurred while dispatching the message, hence message will be retried");
            //We specify an interval to control the retry frequency, as we do not intend to retry sending the message
            //immediately. In this case we wait for 6 seconds if an error occurs
            runtime:sleepCurrentThread(6000);
            //Acknowledge with an error so that the broker would not poll the message from the queue, rather the
            //broker would initiate re-send.
            m.acknowledge(jms:DELIVERY_ERROR);
        }
    }
}
