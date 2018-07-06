//
//  ListPickerView.swift
//  Messenger
//
//  Created by Mike Prince on 2/13/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class ListPickerOptions {
    var screenName:AnalyticsHelper.Screen!
    var result:AnalyticsHelper.Result!
    var selected:String?
    var defaultAccessoryType = UITableViewCellAccessoryType.none
}

class ListPickerViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var listItems:[KeyedLabel]!
    var onSelect:((KeyedLabel)->Void)!
    let tableView = UITableView()
    var options:ListPickerOptions!
    
    class func showPicker(_ nav:UINavigationController,title:String,items:[KeyedLabel], options:ListPickerOptions, onSelect:@escaping (KeyedLabel)->Void ) {
        let vc = ListPickerViewController()
        vc.listItems = items
        vc.options = options
        vc.onSelect = onSelect
        vc.navigationItem.title = title
        nav.pushViewController(vc, animated: true)
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Get main screen bounds
        let screenSize: CGRect = UIScreen.main.bounds
        
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        tableView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight);
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIConstants.LightGrayBackground
        tableView.tableFooterView = UIView()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "myCell")
        
        view.addSubview(tableView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )
        AnalyticsHelper.trackScreen( options.screenName, vc:self )
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return listItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "myCell", for: indexPath)
        
        let row = listItems[indexPath.row]
        cell.textLabel?.text = row.label
        cell.accessoryType = row.key == options.selected ? .checkmark : options.defaultAccessoryType
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        _ = navigationController?.popViewController(animated: true)
        
        let row = listItems[indexPath.row]
        if row.key != options.selected {
            onSelect(row)
            AnalyticsHelper.trackResult(options.result,value:row.key)
        }
    }
}
