//
//  CreateCommand.swift
//  SquirrelToolBox
//
//  Created by Filip Klembara on 8/4/17.
//
//

import SwiftCLI
import PathKit
import SourceGenerator

class CreateCommand: Command {
    let name = "create"
    let shortDescription = "Create model, controller or another file"

    let type = Key<String>("-t", "--type", description: "Values: [model|seeder|layout|view|subview]")
    let typeValues = ["model", "view", "seeder", "layout", "subview"]

    let fileName = Parameter()

    let currentDir = Path().absolute()

    var exeName = ""

    func execute() throws {
        guard let type = type.value, typeValues.contains(type) else {
            throw CLI.Error(message: "Bad value for --type, expected one of [\(typeValues.joined(separator: "|"))]", exitStatus: 1)
        }

        guard let pom = getExecutableName() else {
            throw CLI.Error(message: "Can not get executable name, check if you are in project root directory", exitStatus: 1)
        }

        exeName = pom

        let fileName = self.fileName.value

        guard !fileName.contains(" ") else {
            throw CLI.Error(message: "fileName must be one word character", exitStatus: 1)
        }

        let parts = fileName.split(separator: ".").map({ $0.capitalized })
        let fullName = parts.joined(separator: "/")

        switch type {
        case "model":
            createModel(name: fullName)
        case "view":
            createView(name: fullName)
        case "layout":
            createLayout(name: fullName)
        case "subview":
            createSubview(name: fullName)
        case "seeder":
            createSeeder(name: fullName)
        default:
            throw CLI.Error(message: "Bad value for --type, expected one of [\(typeValues.joined(separator: "|"))], got \(type)", exitStatus: 1)
        }
    }

    private func mkdirs(path: Path) -> Bool {
        let dir = path.parent().absolute()
        if !dir.exists {
            try! dir.mkpath()
        }

        if path.exists {
            guard Input.awaitYesNoInput(message: "File alraady exists, do you want to override it?") else {
                return false
            }
        }
        return true
    }

    private func createSubview(name: String) {
        let file = Path(components: [currentDir.description, "Resources", "Views", "Subviews", name + ".nut"])
        guard mkdirs(path: file) else {
            return
        }

        let string = """
        <!-- \(name).html -->
        <h2>\(name)</name>
        """

        try! file.write(string)
    }

    private func createLayout(name: String) {
        let file = Path(components: [currentDir.description, "Resources", "Views", "Layouts", name.capitalized + ".nut"])
        guard mkdirs(path: file) else {
            return
        }

        let string = """
            <!-- \(name).html -->
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
            </head>
            <body>
                <h1>\(name)</h1>
                \\View()
            </body>
            </html>
            """

        try! file.write(string)
    }

    private func createView(name: String) {

        let file = Path(components: [currentDir.description, "Resources", "Views", "Views", name.capitalized + ".nut"])
        guard mkdirs(path: file) else {
            return
        }

        let string = "<!-- \(name).html -->\n\n\\Title(\"\(name)\")\n\n<h1>\(name)</h1>\n"

        try! file.write(string)
    }

    private func createSeeder(name: String) {
        let seederPath = Path(components: [currentDir.description, "Sources", exeName, "Models", "Database", "Seeders", name.capitalized + "Seeder" + ".swift"])

        guard mkdirs(path: seederPath) else {
            return
        }

        let generator = SourceGenerator()
        generator.imports += ["SquirrelConnector"]
        var modelStruct = SourceStruct(name: seederPath.lastComponentWithoutExtension, protocols: ["Seeder"])

        let initMethod = SourceInit(variables: [])

        modelStruct.inits.append(initMethod)

        var function = SourceFunction(name: "setUp", throws: true, mutating: true)
        let end = "#>"
        function.body.append("models.append(<#" + "Model" + end + ")")
        modelStruct.functions.append(function)
        modelStruct.variables.append(SourceVariable(name: "models", type: "[Model]", value: "[]"))

        generator.content.append(modelStruct)
        try! seederPath.write(generator.generate)
    }

    private func createModel(name: String) {
        let modelPath = Path(components: [currentDir.description, "Sources", exeName, "Models", "Database", "Tables", name.capitalized + ".swift"])

        guard mkdirs(path: modelPath) else {
            return
        }

        let generator = SourceGenerator()
        generator.imports += ["Foundation", "SquirrelConnector"]
        var modelStruct = SourceStruct(name: modelPath.lastComponentWithoutExtension, protocols: ["Model"])
        modelStruct.variables += [
            SourceVariable(name: "id", type: "ObjectId?", value: "nil"),
            SourceVariable(name: "created", value: "Date()"),
            SourceVariable(name: "modified", value: "Date()")
        ]
        generator.content.append(modelStruct)
        try! modelPath.write(generator.generate)
    }
}
