//
//  GermanDate.swift
//
//  Created by Norbert Thies on 30.01.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation

/// A small Date extension to provide German string representations
public extension Date {
  
  /// German week day names
  static let gWeekDays = ["", "Sonntag", "Montag", "Dienstag", "Mittwoch", 
                          "Donnerstag", "Freitag", "Samstag"]
  /// German month names
  static let gMonthNames = ["", "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", 
                            "August", "September", "Oktober", "November", "Dezember"]
  
  /// Returns String in German format: <weekday>, <day>.<monthname> <year>
  func gDateString(tz: String? = nil) -> String {
    let dc = components(tz: tz)
    return "\(Date.gWeekDays[dc.weekday!]), \(dc.day!). " +
           "\(Date.gMonthNames[dc.month!]) \(dc.year!)"
  }
  
  /// German date String in lowercase letters
  func gLowerDateString(tz: String?) -> String {
    return gDateString(tz: tz).lowercased()
  }
  
}
