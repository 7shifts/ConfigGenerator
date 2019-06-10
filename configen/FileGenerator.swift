//
//  FileGenerator.swift
//  configen
//
//  Created by Dónal O'Brien on 11/08/2016.
//  Copyright © 2016 The App Business. All rights reserved.
//

import Foundation

struct FileGenerator {

  let optionsParser: OptionsParser

  var autoGenerationComment: String {
    return """
    // auto-generated by \(optionsParser.appName)\n// to add or remove properties, edit the mapping file: '\(optionsParser.inputHintsFilePath)'.\n// README: https://github.com/theappbusiness/ConfigGenerator/blob/master/README.md\n\n
    """
  }

  func generateHeaderFile(withTemplate template: HeaderTemplate) {

    var headerBodyContent = ""
    optionsParser.sortedHints.forEach { hint in
      let headerLine = methodDeclaration(for: hint, template: template)
      headerBodyContent.append("\n" + headerLine + ";" + "\n")
    }

    var headerBody = template.headerBody
    headerBody.replace(token: template.bodyToken, withString: headerBodyContent)

    do {
      let headerOutputString = autoGenerationComment + template.headerImportStatements + headerBody
      try headerOutputString.write(toFile: template.outputHeaderFileName, atomically: true, encoding: String.Encoding.utf8)
    } catch {
      fatalError("Failed to write to file at path \(template.outputHeaderFileName)")
    }

  }

  func generateImplementationFile(withTemplate template: ImplementationTemplate) {
    var implementationBodyContent = ""
    optionsParser.sortedHints.forEach { hint in
      let implementationLine = methodImplementation(for: hint, template: template)
      implementationBodyContent.append("\n" + implementationLine + "\n")
    }

    var implementationBody = template.implementationBody
    implementationBody.replace(token: template.bodyToken, withString: implementationBodyContent)

    do {
      let implementationOutputString = autoGenerationComment + template.implementationImportStatements + implementationBody
      try implementationOutputString.write(toFile: template.outputImplementationFileName, atomically: true, encoding: String.Encoding.utf8)
    } catch {
      fatalError("Failed to write to file at path \(template.outputImplementationFileName)")
    }

  }

  private func methodDeclaration(for hint: OptionsParser.Hint, template: HeaderTemplate) -> String {
    var line = ""

    switch hint.type {
    case "Double":
      line = template.doubleDeclaration

    case "Int":
      line = template.integerDeclaration

    case "String":
      line = template.stringDeclaration

    case "Bool":
      line = template.booleanDeclaration

    case "URL":
      line = template.urlDeclaration

    default:
      line = template.customDeclaration
      line.replace(token: template.customTypeToken, withString: hint.type)
    }

    line.replace(token: template.variableNameToken, withString: hint.variableName)

    return line
  }

  private func methodImplementation(for hint: OptionsParser.Hint, template: ImplementationTemplate) -> String {

    guard let value = optionsParser.plistDictionary[hint.variableName] else {
      fatalError("No configuration setting for variable name: \(hint.variableName)")
    }

    var line = ""

    switch hint.type {
    case "Double":
      line = template.doubleImplementation

    case "Int":
      line = template.integerImplementation

    case "String":
      line = template.stringImplementation

    case "Bool":
      guard let value = value as? Bool else { fatalError("Not a bool!") }
      let boolString = value ? template.trueString : template.falseString
      line = template.booleanImplementation
      line.replace(token: template.valueToken, withString: boolString)

    case "URL":
      guard let url = URL(string: "\(value)") else { fatalError("Not a URL!") }
      guard url.host != nil else {
        fatalError("Found URL without host: \(url) for setting: \(hint.variableName)")
      }
      line = template.urlImplementation
    case let str where str.match(regex: "^(?:\\[)\\w+(?:\\])$"):
      line = template.customImplementation
      line.replace(token: template.variableNameToken, withString: hint.variableName)
      line.replace(token: template.customTypeToken, withString: hint.type)
      line.replace(token: template.valueToken, withString: formatArrayString(rawValue: value, rawType: str))
      return line

    default:
      guard value is String else {
        fatalError("Value (\(value)) must be a string in order to be used by custom type \(hint.type)")
      }
      line = template.customImplementation
      line.replace(token: template.customTypeToken, withString: hint.type)
    }

    line.replace(token: template.variableNameToken, withString: hint.variableName)
    line.replace(token: template.valueToken, withString: "\(value)")

    return line
  }

  private func formatArrayString(rawValue: AnyObject, rawType: String) -> String {
    var rawTypeCopy = rawType
    var rawValueStr = "\(rawValue)"

    rawTypeCopy = String(rawTypeCopy.dropFirst()) // drop [
    rawTypeCopy = String(rawTypeCopy.dropLast()) // drop ]

    rawValueStr = String(rawValueStr.dropFirst()) // drop (
    rawValueStr = String(rawValueStr.dropLast()) // drop )

    return "Array<\(rawTypeCopy)>(arrayLiteral: \(rawValueStr))"
  }
}

extension String {
  mutating func replace(token: String, withString string: String) {
    self = replacingOccurrences(of: token, with: string)
  }

  var trimmed: String {
    return (self as NSString).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }

  func match(regex: String) -> Bool {
    do {
      let regex = try NSRegularExpression(pattern: regex, options: NSRegularExpression.Options.caseInsensitive)
      let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
      return !matches.isEmpty
    } catch {
      return false
    }
  }
}
