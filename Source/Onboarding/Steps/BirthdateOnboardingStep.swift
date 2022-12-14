//
//  BirthdateOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BirthdateOnboardingStep: OnboardingStep, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    private var birthdate = Date()

    init() {
        super.init(.birthday, buttonStyle: .horizontalStack)
    }
    
    lazy var currentYear: Int = {
        let today = Date()
        let calendar = Calendar.current
        return calendar.component(.year, from: today)
    }()
    
    lazy var years: [Int] = {
        var years = [Int]()
        for i in (currentYear - 99..<currentYear + 1).reversed() {
            years.append(i)
        }
        return years
    }()

    lazy var datePicker: UIPickerView = {
        let picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        picker.backgroundColor = .appBackground
        return picker
    }()

    override func didStart() {
        self.view.textField.becomeFirstResponder()
    }

    override func customizeView() {
        self.view.hintLabel.text = Localized.Onboarding.ageLimit.text
        self.view.textField.inputView = datePicker
        self.view.textField.delegate = self
        // hide the cursor, since we disable direct text editing anyway
        self.view.textField.tintColor = .white
        select(index: 0)
    }

    override func performPrimaryAction(sender button: UIButton) {
        self.data.birthdate = birthdate
        super.performPrimaryAction(sender: button)
    }
    
    private func select(index: Int) {
        guard let selectedDate = Calendar.current.date(byAdding: .year, value: -index, to: Date()) else {
            return
        }
        self.birthdate = selectedDate
        self.view.textField.text = self.birthdate.birthdayString
        if let validDate = Calendar.current.date(byAdding: .year, value: -16, to: Date()) {
            self.view.primaryButton.isEnabled = self.birthdate <= validDate
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        years.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "\(years[row])"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        select(index: row)
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        false
    }
}

fileprivate extension Date {
    var birthdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: self)
    }
}
