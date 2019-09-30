//
//  ViewController.swift
//  SerialGateDemo
//
//  Created by Takuto Nakamura on 2019/02/13.
//  Copyright © 2019 Takuto Nakamura. All rights reserved.
//

import Cocoa
import SerialGate

class ViewController: NSViewController {

    @IBOutlet weak var portsPopUp: NSPopUpButton!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet var textView: NSTextView!
    
    private let manager = SGPortManager.shared
    private var portList = [SGPort]()
    private var port: SGPort? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self
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

    override var representedObject: Any? {
        didSet {
        }
    }

    @IBAction func selectPort(_ sender: NSPopUpButton) {
        port = portList[sender.indexOfSelectedItem]
    }
    
    @IBAction func pushButton(_ sender: NSButton) {
        if sender.tag == 0 { // open
            port?.delegate = self
            port?.baudRate = B9600
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
    
}

// ★★ SGPortManagerDelegate ★★ //
extension ViewController: SGPortManagerDelegate {

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
    
}

// ★★ SGPortDelegate ★★ //
extension ViewController: SGPortDelegate {
    
    func received(_ texts: [String]) {
        DispatchQueue.main.async {
            self.textView.string += texts.joined(separator: "\n") + "\n"
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
