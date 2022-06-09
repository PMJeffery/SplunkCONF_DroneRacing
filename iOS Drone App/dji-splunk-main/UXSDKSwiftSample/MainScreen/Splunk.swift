//
//  Splunk.swift
//  UXSDKSwiftSample
//
//  Created by Amin Hamidi on 6/2/22.
//  Copyright © 2022 DJI. All rights reserved.
//

import SwiftUI
import DJISDK
import DJIUXSDK
import DJISDK.DJIFlightController
import DJISDK.DJIFlightControllerState

@available(iOS 14.0, *)
struct Splunk: View {
    //default values for testing will be overwritten by inputs
    @State var splunkURI: String = "http://108.51.167.13:8088/services/collector"
    @State var hec: String = "Splunk 69d2b86d-6cd6-480d-acfa-c3213604fe94"
    @State var status: String = ""
    @State var participantID = ""
    
    var body: some View {
        VStack {
            
            TextField("Enter Splunk URI", text: $splunkURI)
                .textFieldStyle(.roundedBorder)
            TextField("Enter HEC Token", text: $hec)
                .textFieldStyle(.roundedBorder)
            TextField("Enter Partipant ID", text: $participantID)
                .textFieldStyle(.roundedBorder)
            Divider()
            Button("Check splunk connection") {
                //check connection to splunk, and setup timing
                    //to submit logs
                sendToSplk()
                //pass in self to give timer access to state variables w/o managing it's own state
                var logger = SplunkHECLogger()
                logger.initTimer(splunkView:self)
                //setup timer to log in bck
//                if(self.status.contains("Success")){
//                    SplunkHECLogger.initTimer()
//
//                }
            }
            .buttonStyle(GrowingButton())
            .padding()
            
            if status != "" {
                Text(self.status.contains("Success") ? "Connected to Splunk \(Image(systemName: "checkmark.circle.fill"))" : "Failed to connect to Splunk \(Image(systemName: "x.circle.fill"))")
                    .font(.system(size: 30)).padding()
            }
            
            
            Spacer()
        }
    }
}

//function to init a post to splunk of data and/or to check the connection
//pass in no msg in order to do a check of the connection
//pass in well formed message to post log to splunk
@available(iOS 14.0, *)
extension Splunk {
    func sendToSplk(msg: [String: AnyHashable] = ["source":"splunk-dji-app","sourcetype":"dji-app-connect","event": "Successfully Connected to Splunk HEC"])  {
        //let msg: [String: AnyHashable] =

        let jsonData = try? JSONSerialization.data(withJSONObject: msg)
        
        let url = URL(string: self.splunkURI)!
        var request = URLRequest(url: url)
        request.setValue(self.hec, forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "woah")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
                self.status = responseJSON.description
            }
        }
        task.resume()
    }
    
}

@available(iOS 14.0.0, *)
struct Splunk_Previews: PreviewProvider {
    static var previews: some View {
        Splunk()
    }
}

@available(iOS 14.0.0, *)
struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color(red: 0, green: 0, blue: 1))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

//class responsible for performing background logging into splunk. must be setup and given a timer via it's init function
@available(iOS 14.0.0, *)
class SplunkHECLogger : NSObject, DJIFlightControllerDelegate, DJIBatteryDelegate {
    
    static let shared = SplunkHECLogger()
    //setup including time for bckRunning, current state value, and connection to UI
    static var submitTimer : Timer?;
    var currentState :DJIFlightControllerState?
    var controller : DJIFlightController?
    var splunkView : Splunk?
    var aircraft : DJIAircraft?
    var batteryCurrentState : DJIBatteryState?

//    var stateSync = DroneSplunkStateSync()
    //static var delegate :DJIFlightControllerDelegate?
    
    func initTimer(splunkView: Splunk){
//        print("init timer: \(Self.submitTimer)")
        //print("creating timer")
        //stateSync?.delegate = self
        self.splunkView = splunkView
        //check if timer is already initialized. if so deallocate and re-init
        if (Self.submitTimer != nil){
            print("already have a timer")
            //de-allocate old timer and setup new one
            Self.submitTimer?.invalidate();
            print("invalidatingTimer")
            Self.submitTimer = nil;
            
        }
        guard let aircraft = DJISDKManager.product() as? DJIAircraft else {
            //log error to splunk no aircraft reachable
            return
        }

        
        //aircraft.flightController!.delegate = delegate
        self.aircraft = aircraft
        self.aircraft?.battery?.delegate = self
        self.controller = aircraft.flightController
        self.controller?.delegate = self
        
        //DJIFlightControllerState.initialize();
        self.batteryCurrentState = DJIBatteryState.init()
        self.currentState = DJIFlightControllerState.init();
        //initialize timer by default to every 1 seconds to send data from drone into splunk
        let submitTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(SplunkHECLogger.backgroundLogging), userInfo: nil, repeats: true)
        Self.submitTimer = submitTimer
//        print("end timer: \(Self.submitTimer)")

        return
    }
    
    //kick off logging to HEC
    @objc func backgroundLogging(){
        //exit if the aircraft cannot be reache
        //interface with FlightControllerState to pull logs
        //print(DJISDK.DJISDKManager.product())
        //Submit to HEC
        print("Logging to Splunk")
        self.splunkView?.sendToSplk(msg: formatForHEC(state:currentState!, batteryState: batteryCurrentState!))

        //close
    }
    
    //function to format calls from FlightControllerState into a HEC-able HTTP msg format
    func formatForHEC(state: DJIFlightControllerState, batteryState: DJIBatteryState) -> [String:AnyHashable]{
        var aircraftState = ["aircraftModel":self.aircraft?.model,"altitude":state.altitude.description,"isFlying":state.isFlying.description,"velocityX":state.velocityX.description,"velocityY":state.velocityY.description,"velocityZ":state.velocityZ.description,"areMotorsOn":state.areMotorsOn.description,"flightTimeInSeconds":state.flightTimeInSeconds.description,
                     "isLowerThanBatteryWarningThreshold":state.isLowerThanBatteryWarningThreshold.description,"isLowerThanSeriousBatteryWarningThreshold": state.isLowerThanSeriousBatteryWarningThreshold.description,"participantID":self.splunkView?.participantID.description,"countOfFlights":state.countOfFlights.description,"flightMode":state.flightModeString,"satelliteCount":state.satelliteCount.description,"attitude.pitch":state.attitude.pitch.description,"attitude.yaw":state.attitude.yaw.description,"attitude.roll":state.attitude.roll.description,
                             "ultrasonicHeightInMeters":state.ultrasonicHeightInMeters.description,"chargeRemaining":batteryState.chargeRemaining.description,"chargeRemainingInPercent":batteryState.chargeRemainingInPercent.description,
                             "isBeingCharged":batteryState.isBeingCharged.description,"numberOfDischarges":batteryState.numberOfDischarges.description,"batteryTemperature":batteryState.temperature.description,"batteryVoltage":batteryState.voltage.description]
//
        return ["time": Date().timeIntervalSince1970.description,"source":"splunk-dji-app","sourcetype":"dji-app","index":"drones", "event":aircraftState]
    }
    
    
    //delegate method to update the current state of flightController
    @objc(flightController:didUpdateState:) func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
//        print(state.isFlying)
        self.currentState = state;
    }
    
    //delegate to update battery's state
    @objc func battery(_ battery: DJIBattery, didUpdate state: DJIBatteryState) {
        self.batteryCurrentState = state;
    }
}

//class DroneSplunkStateSync : NSObject, DJIFlightControllerDelegate{
//    weak var delegate : DJIFlightControllerDelegate?
//    var controller : DJIFlightController?
//
//    override init() {
//        super.init()
//        print("created DroneStateSync")
//
//    }
//
//    @objc func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
//        print("CALLED SPL DELEGATE")
//
//    }
//

