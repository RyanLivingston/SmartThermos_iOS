//
//  ViewController.swift
//  CBTester
//
//  Created by Ryan Livingston on 3/11/19.
//  Copyright © 2019 Ryan Livingston. All rights reserved.
//

import UIKit
import CoreBluetooth

// Declare bluetooth service and characterisitc UUID's
let BLE_Service_CBUUID = CBUUID(string: "0x1234")
let BLE_Characterstic_SetTemp_CBUUID = CBUUID(string: "0x2001")
let BLE_Characterstic_ActualTemp_CBUUID = CBUUID(string: "0x2002")
let BLE_Characterstic_Battery_CBUUID = CBUUID(string: "0x2003")
let BLE_Characterstic_OpState_CBUUID = CBUUID(string: "0x2004")
let BLE_Characterstic_OpStatus_CBUUID = CBUUID(string: "0x2005")

// Declare all possible states of the application
enum ViewState {
    case connected
    case disconnected
    case BTPoweredOff
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // ViewController variables
    var BTCentralManager: CBCentralManager?
    var BTPeripheral: CBPeripheral?
    
    var SetTempCharacteristic: CBCharacteristic?
    var SetTemperature: Int?
    var SetTemperatureAsString: String?
    
    var OpStateCharacteristic: CBCharacteristic?
    
    @IBOutlet weak var ConnectionLabel: UILabel!
    @IBOutlet weak var PeripheralNameLabel: UILabel!
    @IBOutlet weak var SetTempStepper: UIStepper!
    @IBOutlet weak var SetTempLabel: UILabel!
    @IBOutlet weak var ActualTempLabel: UILabel!
    @IBOutlet weak var ActualTempTextField: UITextField!
    @IBOutlet weak var BatteryLabel: UILabel!
    @IBOutlet weak var BatteryTextField: UITextField!
    @IBOutlet weak var StateSwitch: UISwitch!
    @IBOutlet weak var StatusLabel: UILabel!
    
    // Handle change in operation state button
    @IBAction func StateSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            StatusLabel.text = "Ready!"
            StatusLabel.textColor = UIColor.green
        }
        else {
            StatusLabel.text = "Standby"
            StatusLabel.textColor = UIColor.black
        }
        
        // Send the updated operation state to the microcontroller
        writeCharacteristic(val: UInt8(sender.isOn ? 1 : 0), for: OpStateCharacteristic!)
    }
    
    // Handle change in set temperature stepper button(s)
    @IBAction func SetTempStepperChanged(_ sender: UIStepper) {
        SetTemperature = Int(sender.value)
        
        SetTemperatureAsString = SetTemperature?.description
        SetTemperatureAsString! += "\u{00B0}F"
        
        // Format and update the set temp label
        SetTempLabel.text = SetTemperatureAsString
        
        //Send the updated set temp to the microcontroller
        writeCharacteristic(val: UInt8(SetTemperature!), for: SetTempCharacteristic!)
        
    }
    
    // Called upon app initally loading
    override func viewDidLoad() {
        // Construct parent view controller class
        super.viewDidLoad()
        
        SetTempStepper.autorepeat = true
        
        // Initialize the BT central manager
        BTCentralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Check the bluetooth status of the device
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        // If powered on then begin scanning for peripherals
        if central.state == .poweredOn {
            
            print("Bluetooth Powered ON")
            
            changeViewState(to: .disconnected)
            
            // Scan for peripherals
            print("Scanning...")
            BTCentralManager?.scanForPeripherals(withServices: [BLE_Service_CBUUID])
        }
        // Else send app to BT powered off state
        else{
            print("Bluetooth not powered ON!")
            changeViewState(to: .BTPoweredOff)
        }
    }
    
    // Called when a peripheral is found
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        print("Found: \(peripheral.name!)")
        
        // Initalize the peripheral, stop scanning, and connect
        BTPeripheral = peripheral
        BTPeripheral?.delegate = self
        
        BTCentralManager?.stopScan()
        BTCentralManager?.connect(BTPeripheral!)
    }
    
    // Called when sucessfully connected to peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        changeViewState(to: .connected)
        PeripheralNameLabel.text = peripheral.name
        
        // Discover the peripheral services
        BTPeripheral?.discoverServices([BLE_Service_CBUUID])
    }
    
    // Called when peripheral is disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        print("Disconnected!")
        changeViewState(to: .disconnected)
        
        // Re-scan for peripheral
        print("Scanning...")
        BTCentralManager?.scanForPeripherals(withServices: [BLE_Service_CBUUID])
    }
    
    // Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        // Check each service and discover the characteristics of each service
        for service in peripheral.services! {
            if service.uuid == BLE_Service_CBUUID {
                
                print("Service: \(service)")

                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    // Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        // Test each characteristic and either set it to be read or set it as a notification
        for characteristic in service.characteristics! {
            
            if characteristic.uuid.isEqual(BLE_Characterstic_SetTemp_CBUUID) {
                SetTempCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            }
            if characteristic.uuid.isEqual(BLE_Characterstic_OpState_CBUUID) {
                OpStateCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            }
            if characteristic.uuid.isEqual(BLE_Characterstic_ActualTemp_CBUUID) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Notify: \(characteristic)")
            }
            if characteristic.uuid.isEqual(BLE_Characterstic_Battery_CBUUID) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Notify: \(characteristic)")
            }
            if characteristic.uuid.isEqual(BLE_Characterstic_OpStatus_CBUUID) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Notify: \(characteristic)")
            }
        }
    }
    
    // Called when a characteristic is updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // If the Set Temp is updated
        if characteristic.uuid.isEqual(BLE_Characterstic_SetTemp_CBUUID) {
            print("Read: \(characteristic)")
            
            // Set the stepper and set simulate a button press to change the label
            SetTempStepper.value = Double(unwrapCharacteristicData(for: characteristic))
            SetTempStepper.sendActions(for: UIControl.Event.valueChanged)
        }
        // If the Op State is updated
        if characteristic.uuid.isEqual(BLE_Characterstic_OpState_CBUUID) {
            print("Read: \(characteristic)")
            
            // Unwrap the payload
            let stateInt = Int(unwrapCharacteristicData(for: characteristic))
            
            // Set the Op State switch accordingly
            StateSwitch.setOn((stateInt as NSNumber).boolValue, animated: true)
            StateSwitch.sendActions(for: UIControl.Event.valueChanged)
        }
        // If the Actual Temp is updated
        if characteristic.uuid.isEqual(BLE_Characterstic_ActualTemp_CBUUID) {
            
            // Unwrap the payload
            var ActualTemp = unwrapCharacteristicData(for: characteristic).description
            
            // Format the value and update the text field
            ActualTemp += "\u{00B0}F"
            ActualTempTextField.text = ActualTemp
            print("Notified: <Actual_Temp: \(ActualTemp)>")
        }
        // If the Battery Level is updated
        if characteristic.uuid.isEqual(BLE_Characterstic_Battery_CBUUID) {
            
            // Unwrap the payload
            var BatteryLevel = unwrapCharacteristicData(for: characteristic).description
            
            // Format the value and update the text field
            BatteryLevel += "%"
            BatteryTextField.text = BatteryLevel
            print("Notified: <Battery: \(BatteryLevel)>");
        }
        // If the Op Status is updated (0 = not heating, 1 = HEATING)
        if characteristic.uuid.isEqual(BLE_Characterstic_OpStatus_CBUUID) {
            
            // Unwrap the payload
            let statusInt = Int(unwrapCharacteristicData(for: characteristic))
            
            print("Notified: <Op_Status: \(statusInt)>");
            
            // If the status is 0 then set the app to "Ready" (Not heating)
            if statusInt == 0 {
                StatusLabel.text = "Ready!"
                StatusLabel.textColor = UIColor.green
            }
            // Else set the status to "Heating"
            else {
                StatusLabel.text = "Heating!"
                StatusLabel.textColor = UIColor.red
            }
        }
    }
    
    // Upwrap/cast the characteristic payload and return as UInt8
    func unwrapCharacteristicData(for characteristic: CBCharacteristic) -> UInt8 {
        let  dataAsInt = [UInt8](characteristic.value!)
        return dataAsInt[0];
    }

    // Write value to BLE characteristic
    func writeCharacteristic(val: UInt8, for characteristic: CBCharacteristic){
        var val = val
        let ns = NSData(bytes: &val, length: MemoryLayout<UInt8>.size)
        BTPeripheral!.writeValue(ns as Data, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    // Change the app view state
    func changeViewState(to state: ViewState) {
        
        switch state {
        case .connected:
            SetTempStepper.isEnabled = true
            ConnectionLabel.text = "Connected"
            ConnectionLabel.textColor = UIColor.green
            StateSwitch.isEnabled = true
            
        case .disconnected:
            SetTempStepper.isEnabled = false
            SetTempLabel.text = "N/A"
            ConnectionLabel.text = "Disconnected"
            ConnectionLabel.textColor = UIColor.red
            PeripheralNameLabel.text = "Searching..."
            StateSwitch.isEnabled = false
            StateSwitch.isOn = false
            StatusLabel.text = "StandBy"
            StatusLabel.textColor = UIColor.black
            ActualTempTextField.text = "N/A"
            BatteryTextField.text = "N/A"
            
        case .BTPoweredOff:
            SetTempStepper.isEnabled = false
            SetTempLabel.text = "N/A"
            ConnectionLabel.text = "ENABLE BLUETOOTH!"
            ConnectionLabel.textColor = UIColor.red
            PeripheralNameLabel.text = "---"
            StateSwitch.isEnabled = false
            StateSwitch.isOn = false
            StatusLabel.text = "StandBy"
            StatusLabel.textColor = UIColor.black
            ActualTempTextField.text = "N/A"
            BatteryTextField.text = "N/A"
        }
    }
}

