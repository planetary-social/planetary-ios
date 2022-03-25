import Foundation

extension NSObject {

    /// Class name is useful property to associate classes to
    /// other data via a String.  Check out DebugTableViewController
    /// and see how table view cell class names are used to register
    /// cell reuse identifiers with the parent table.
    ///
    /// An important detail about this property is that it will return
    /// a String name of the top most class in the inheritance hierarchy.
    /// If you're looking for the name of the super class, you must first
    /// have an instance of the class, then downcast it for the desired
    /// name.
    static var className: String {
        String(describing: self)
    }
}
