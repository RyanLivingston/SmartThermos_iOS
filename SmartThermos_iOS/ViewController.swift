//
//  ViewController.swift
//  CBTester
//
//  Created by Ryan Livingston on 3/11/19.
//  Copyright © 2019 Ryan Livingston. All rights reserved.
//

import UIKit
import CoreBluetooth

let BLE_Service_CBUUID = CBUUID(string: "0x1234")
let BLE_Characterstic_SetTemp_CBUUID = CBUUID(string: "0x2001")
let BLE_Characterstic_ActualTemp_CBUUID = CBUUID(string: "0x2002")
let BLE_Characterstic_Battery_CBUUID = CBUUID(string: "0x2003")
let BLE_Characterstic_OpState_CBUUID = CBUUID(string: "0x2004")
let BLE_Characterstic_OpStatus_CBUUID = CBUUID(string: "0x2005")

enum ViewState {
    case connected
    case disconnected
    case BTPoweredOff
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
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
    
    @IBAction func StateSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            StatusLabel.text = "Ready!"
            StatusLabel.textColor = UIColor.green
        }
        else {
            StatusLabel.text = "Standby"
            StatusLabel.textColor = UIColor.black
        }
        
        writeCharacteristic(val: UInt8(sender.isOn ? 1 : 0), for: OpStateCharacteristic!)
    }
    
    @IBAction func SetTempStepperChanged(_ sender: UIStepper) {
        SetTemperature = Int(sender.value)
        
        SetTemperatureAsString = SetTemperature?.description
        SetTemperatureAsString! += "\u{00B0}F"
        
        SetTempLabel.text = SetTemperatureAsString
        
        writeCharacteristic(val: UInt8(SetTemperature!), for: SetTempCharacteristic!)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SetTempStepper.autorepeat = true
        BTCentralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            
            print("Bluetooth Powered ON")
            
            changeViewState(to: .disconnected)
            
            // Scan for peripherals
            print("Scanning...")
            BTCentralManager?.scanForPeripherals(withServices: [BLE_Service_CBUUID])
        }
        else{
            print("Bluetooth not powered ON!")
            changeViewState(to: .BTPoweredOff)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        print("Found: \(peripheral.name!)")
        
        BTPeripheral = peripheral
        BTPeripheral?.delegate = self
        
        BTCentralManager?.stopScan()
        BTCentralManager?.connect(BTPeripheral!)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        changeViewState(to: .connected)
        PeripheralNameLabel.text = peripheral.name
        
        BTPeripheral?.discoverServices([BLE_Service_CBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        print("Disconnected!")
        changeViewState(to: .disconnected)
        
        print("Scanning...")
        BTCentralManager?.scanForPeripherals(withServices: [BLE_Service_CBUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            if service.uuid == BLE_Service_CBUUID {
                
                print("Service: \(service)")

                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
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
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid.isEqual(BLE_Characterstic_SetTemp_CBUUID) {
            print("Read: \(characteristic)")
            
            SetTempStepper.value = Double(unwrapCharacteristicData(for: characteristic))
            SetTempStepper.sendActions(for: UIControl.Event.valueChanged)
        }
        if characteristic.uuid.isEqual(BLE_Characterstic_OpState_CBUUID) {
            print("Read: \(characteristic)")
            let stateInt = Int(unwrapCharacteristicData(for: characteristic))
            
            StateSwitch.setOn((stateInt as NSNumber).boolValue, animated: true)
            StateSwitch.sendActions(for: UIControl.Event.valueChanged)
        }
        if characteristic.uuid.isEqual(BLE_Characterstic_ActualTemp_CBUUID) {
            var ActualTemp = unwrapCharacteristicData(for: characteristic).description
            ActualTemp += "\u{00B0}F"
            ActualTempTextField.text = ActualTemp
            print("Notified: <Actual_Temp: \(ActualTemp)>")
        }
        if characteristic.uuid.isEqual(BLE_Characterstic_Battery_CBUUID) {
            var BatteryLevel = unwrapCharacteristicData(for: characteristic).description
            BatteryLevel += "%"
            BatteryTextField.text = BatteryLevel
            print("Notified: <Battery: \(BatteryLevel)>");
        }
        if characteristic.uuid.isEqual(BLE_Characterstic_OpStatus_CBUUID) {
            let statusInt = Int(unwrapCharacteristicData(for: characteristic))
            
            print("Notified: <Op_Status: \(statusInt)>");
            
            if statusInt == 0 {
                StatusLabel.text = "Ready!"
                StatusLabel.textColor = UIColor.green
            }
            else {
                StatusLabel.text = "Heating!"
                StatusLabel.textColor = UIColor.red
            }
        }
    }
    
    func unwrapCharacteristicData(for characteristic: CBCharacteristic) -> UInt8 {
        let  dataAsInt = [UInt8](characteristic.value!)
        return dataAsInt[0];
    }

    func writeCharacteristic(val: UInt8, for characteristic: CBCharacteristic){
        var val = val
        let ns = NSData(bytes: &val, length: MemoryLayout<UInt8>.size)
        BTPeripheral!.writeValue(ns as Data, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
    }
    
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

