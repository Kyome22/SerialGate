import Darwin
import Foundation

func logput(
    _ items: Any...,
    file: String = #file,
    line: Int = #line,
    function: String = #function
) {
#if DEBUG
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    var array: [Any] = ["💫Log: \(fileName)", "Line:\(line)", function]
    array.append(contentsOf: items)
    Swift.print(array)
#endif
}

extension termios {
    mutating func updateC_CC(_ n: Int32, v: UInt8) {
        switch n {
        case  0: c_cc.0  = v
        case  1: c_cc.1  = v
        case  2: c_cc.2  = v
        case  3: c_cc.3  = v
        case  4: c_cc.4  = v
        case  5: c_cc.5  = v
        case  6: c_cc.6  = v
        case  7: c_cc.7  = v
        case  8: c_cc.8  = v
        case  9: c_cc.9  = v
        case 10: c_cc.10 = v
        case 11: c_cc.11 = v
        case 12: c_cc.12 = v
        case 13: c_cc.13 = v
        case 14: c_cc.14 = v
        case 15: c_cc.15 = v
        case 16: c_cc.16 = v
        case 17: c_cc.17 = v
        case 18: c_cc.18 = v
        case 19: c_cc.19 = v
        default: break
        }
    }
}
