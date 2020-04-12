//
//  ViewController.swift
//  SerialGateDemo
//
//  Created by Takuto Nakamura on 2019/02/13.
//  Copyright © 2019 Takuto Nakamura. All rights reserved.
//

import Cocoa
import SerialGate

// with Test_for_SerialGate Arduino Program
class ViewController: NSViewController {

    @IBOutlet weak var portsPopUp: NSPopUpButton!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet var textView: NSTextView!
    
    private let manager = SGPortManager.shared
    private var portList = [SGPort]()
    private var port: SGPort? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.updatedAvailablePortsHandler = { [weak self] in
            self?.updatedAvailablePorts()
        }
        portList = manager.availablePorts
        portsPopUp.removeAllItems()
        portList.forEach { (port) in
            portsPopUp.addItem(withTitle: port.name)
        }
        port = portList.first
    }
    
    override func viewWillDisappear() {
        port?.close()
    }

    @IBAction func selectPort(_ sender: NSPopUpButton) {
        port = portList[sender.indexOfSelectedItem]
    }
    
    @IBAction func pushButton(_ sender: NSButton) {
        if sender.tag == 0 { // open
            port?.baudRate = B9600
            port?.portOpenedHandler = { [weak self] (port) in
                self?.portWasOpened(port)
            }
            port?.portClosedHandler = { [weak self] (port) in
                self?.portWasClosed(port)
            }
            port?.portClosedHandler = { [weak self] (port) in
                self?.portWasClosed(port)
            }
            port?.receivedHandler = { [weak self] (text) in
                self?.received(text)
            }
            port?.failureOpenHandler = { (port) in
                Swift.print("Failure Open Port \(port.name)")
            }
            port?.open()
            portsPopUp.isEnabled = false
            textView.string = ""
        } else if sender.tag == 1 { // close
            port?.close()
            portsPopUp.isEnabled = true
        } else { // send
            let text = textField.stringValue
            if text.count > 0 {
                port?.send(text)
            }
        }
    }
    
    // MARK: ★★ SGPortManager Handler ★★
    func updatedAvailablePorts() {
        portList = manager.availablePorts
        portsPopUp.removeAllItems()
        portList.forEach { (port) in
            portsPopUp.addItem(withTitle: port.name)
        }
        
        if portList.contains(where: { (portInList) -> Bool in
            return portInList.name == port!.name
        }) {
            portsPopUp.selectItem(withTitle: port!.name)
        } else {
            portsPopUp.isEnabled = true
            port = portList.first
        }
    }
    
    // MARK: ★★ SGPortDelegate ★★
    func received(_ text: String) {
        DispatchQueue.main.async {
            self.textView.string += text
            self.textView.scrollToEndOfDocument(nil)
        }
    }
    
    func portWasOpened(_ port: SGPort) {
        Swift.print("Port: \(port.name) Opend")
    }
    
    func portWasClosed(_ port: SGPort) {
        Swift.print("Port: \(port.name) Closed")
    }
    
    func portWasRemoved(_ port: SGPort) {
        Swift.print("Port: \(port.name) Removed")
    }
    
}
