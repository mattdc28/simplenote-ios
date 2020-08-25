import UIKit
import CoreSpotlight

/// A class used to display options for the note that is currently being edited
class NoteOptionsViewController: UITableViewController {

    /// Array of `Section`s to display in the view.
    /// Each `Section` has `Rows` that are used for display
    fileprivate var sections: [Section] {
        return [optionsSection, linkSection, collaborationSection, trashSection]
    }

    /// The note from the editor that we will change settings for
    fileprivate var note: Note

    /// The delegate to notify about
    /// chaanges made here
    weak var delegate: NoteOptionsViewControllerDelegate?

    /// Formats number of collaborators to respect locales
    private var collaboratorNumberFormatter = NumberFormatter()

    /// Activity indicator that displays when note is publishing or unpublishing
    private var publishActivityIndicator = UIActivityIndicatorView(style: SPUserInterface.isDark ? .white : .gray)

    /// Initialises the options view for a specific note
    /// - Parameter note: The note to configure options for
    init(with note: Note) {
        self.note = note
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("This view cannot be initialised through Storyboards")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Options", comment: "Note Options: Title")
        setupDoneButton()
        setupViewStyles()
        registerTableCells()
    }

    // MARK: - View Setup
    /// Configures a dismiss button for the navigation bar
    func setupDoneButton() {
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: "Note options: Done"),
                                         style: .done,
                                         target: self,
                                         action: #selector(handleDone(button:)))
        doneButton.accessibilityHint = NSLocalizedString("Dismisses the note options view", comment: "Accessibility hint for dismissing the note options view")
        navigationItem.rightBarButtonItem = doneButton
    }

    /// Applies Simplenote styling to the view controller
    func setupViewStyles() {
        tableView.backgroundColor = .simplenoteTableViewBackgroundColor
        tableView.separatorColor = .simplenoteDividerColor
    }

    // MARK: - Table helpers
    /// Registers cell types that can be displayed by the note options view
    func registerTableCells() {
        for rowStyle in Row.Style.allCases {
            tableView.register(rowStyle.cellType, forCellReuseIdentifier: rowStyle.rawValue)
        }
    }

    /// Called by the presenting view when Simperium
    /// has delivered updates for the `note`
    @objc
    public func didReceiveNoteUpdate() {
        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = cellFor(row: row, at: indexPath)
        row.configuration?(cell, row)
        return cell
    }

    fileprivate func cellFor(row: Row, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: row.style.rawValue, for: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerText
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerText
    }

    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = sections[indexPath.section].rows[indexPath.row]
        row.handler?(indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Table Sections
    /// Configures a section to display our main options in
    fileprivate var optionsSection: Section {
        let rows = [
            Row(style: .Switch,
                configuration: { [weak self, note] (cell: UITableViewCell, row: Row) in
                    let cell = cell as! SwitchTableViewCell
                    cell.textLabel?.text = NSLocalizedString("Pin to Top", comment: "Note Options: Pin to Top")
                    cell.cellSwitch.addTarget(self, action: #selector(self?.handlePinToTop(sender:)), for: .primaryActionTriggered)
                    cell.cellSwitch.accessibilityLabel = NSLocalizedString("Pin toggle", comment: "Switch which marks a note as pinned or unpinned")
                    cell.cellSwitch.accessibilityHint = note.pinned ?
                        NSLocalizedString("Unpin note", comment: "Action to mark a note as unpinned") :
                        NSLocalizedString("Pin note", comment: "Action to mark a note as pinned")
                    cell.cellSwitch.isOn = note.pinned
                }
            ),
            Row(style: .Switch,
                configuration: { [weak self, note] (cell: UITableViewCell, row: Row) in
                    let cell = cell as! SwitchTableViewCell
                    cell.textLabel?.text = NSLocalizedString("Markdown", comment: "Note Options: Toggle Markdown")
                    cell.cellSwitch.addTarget(self, action: #selector(self?.handleMarkdown(sender:)), for: .primaryActionTriggered)
                    cell.cellSwitch.accessibilityLabel = NSLocalizedString("Markdown toggle", comment: "Switch which marks a note as using Markdown formatting or not")
                    cell.cellSwitch.accessibilityHint = note.markdown ?
                        NSLocalizedString("Disable Markdown formatting", comment: "Accessibility hint for disabling markdown mode") :
                        NSLocalizedString("Enable Markdown formatting", comment: "Accessibility hint for enabling markdown mode")
                    cell.cellSwitch.isOn = note.markdown
                }
            ),
            Row(style: .Value1,
                configuration: { (cell: UITableViewCell, row: Row) in
                    let cell = cell as! Value1TableViewCell
                    cell.textLabel?.text = NSLocalizedString("Share", comment: "Note Options: Show Share Options")
                    cell.accessibilityHint = NSLocalizedString("share-accessibility-hint", comment: "Accessibility hint on share button")
                },
                handler: { [weak self] (indexPath: IndexPath) in
                    self?.handleShare(from: indexPath)
                }
            ),
            Row(style: .Value1,
                configuration: { (cell: UITableViewCell, row: Row) in
                    let cell = cell as! Value1TableViewCell
                    cell.textLabel?.text = NSLocalizedString("History", comment: "Note Options: Show History")
                    cell.accessibilityHint = NSLocalizedString("history-accessibility-hint", comment: "Accessibility hint on button which shows the history of a notew")
                },
                handler: { [weak self] (indexPath: IndexPath) in
                    self?.handleHistory()
                }
            )
        ]
        return Section(rows: rows)
    }

    /// Configures a section to display our link options in
    fileprivate var linkSection: Section {
        let rows = [
            Row(style: .Switch,
                configuration: { [weak self, note] (cell: UITableViewCell, row: Row) in
                    let cell = cell as! SwitchTableViewCell
                    cell.textLabel?.text = NSLocalizedString("Publish", comment: "Note Options: Publish")
                    cell.cellSwitch.addTarget(self, action: #selector(self?.handlePublish(sender:)), for: .primaryActionTriggered)
                    cell.cellSwitch.accessibilityLabel = NSLocalizedString("Publish toggle", comment: "Switch which marks a note as published or unpublished")
                    cell.cellSwitch.accessibilityHint = note.published ?
                        NSLocalizedString("Unpublish note", comment: "Action which unpublishes a note") :
                        NSLocalizedString("Publish note", comment: "Action which published a note to a web page")
                    cell.cellSwitch.isOn = note.published
                }
            ),
            Row(style: .Value1,
                configuration: { [publishActivityIndicator, note] (cell: UITableViewCell, row: Row) in
                    let cell = cell as! Value1TableViewCell
                    cell.textLabel?.text = NSLocalizedString("Copy Link", comment: "Note Options: Copy Link")
                    cell.textLabel?.textColor = !note.publishURL.isEmpty ? .simplenoteTextColor : .simplenoteGray20Color
                    cell.accessibilityHint = NSLocalizedString("Tap to copy link", comment: "Accessibility hint on cell that copies public URL of note")
                    cell.isUserInteractionEnabled = !note.publishURL.isEmpty
                    cell.accessoryView = publishActivityIndicator

                    if (note.published && note.publishURL.isEmpty ||
                        !note.published && !note.publishURL.isEmpty) {
                        publishActivityIndicator.startAnimating()
                    }
                },
                handler: { [weak self] (indexPath: IndexPath) in
                    self?.handleCopyLink(from: indexPath)
                }
            )
        ]
        return Section(headerText: NSLocalizedString("Public Link", comment: "Note Options Header: Public Link"),
                       footerText: NSLocalizedString("Publish your note to the web and generate a shareable URL", comment: "Note Options Footer: Publish your note to generate a URL"),
                       rows: rows)
    }

    /// Configures a section to display our collaboration details
    fileprivate var collaborationSection: Section {
        let rows = [
            Row(style: .Value1,
                configuration: { [note, collaboratorNumberFormatter] (cell: UITableViewCell, row: Row) in
                    let cell = cell as! Value1TableViewCell
                    cell.textLabel?.text = NSLocalizedString("Collaborate", comment: "Note Options: Collaborate")
                    cell.detailTextLabel?.text = collaboratorNumberFormatter.string(from: NSNumber(value: note.emailTagsArray.count))
                    cell.accessibilityHint = NSLocalizedString("collaborate-accessibility-hint", comment: "Accessibility hint on button which shows the current collaborators on a note")
                },
                handler: { [weak self] (indexPath: IndexPath) in
                    self?.handleCollaborate(from: indexPath)
                }
            )
        ]
        return Section(rows: rows)
    }

    /// Configures a section to display our trash options
    fileprivate var trashSection: Section {
        let rows = [
            Row(style: .Value1,
                configuration: { (cell: UITableViewCell, row: Row) in
                    let cell = cell as! Value1TableViewCell
                    cell.textLabel?.text = NSLocalizedString("Move to Trash", comment: "Note Options: Move to Trash")
                    cell.textLabel?.textColor = .simplenoteDestructiveActionColor
                    cell.accessibilityHint = NSLocalizedString("trash-accessibility-hint", comment: "Accessibility hint on button which moves a note to the trash")
                },
                handler: { [weak self] (indexPath: IndexPath) in
                    self?.handleMoveToTrash()
                }
            )
        ]
        return Section(rows: rows)
    }

    // MARK: - Private Nested Classes
    /// Contains all data required to render a `UITableView` section
    fileprivate struct Section {
        /// Optional text to display as standard header text above the `UITableView` section
        let headerText: String?

        /// Optional text to display as standard footer text below the `UITableView` section
        let footerText: String?

        /// Any rows to be displayed inside this `UITableView` section
        let rows: [Row]

        internal init(headerText: String? = nil, footerText: String? = nil, rows: [Row]) {
            self.headerText = headerText
            self.footerText = footerText
            self.rows = rows
        }
    }

    /// Contains all the data required to render a row
    fileprivate struct Row {
        /// Determines what cell is used to render this row
        let style: Style

        /// Called to set up this cell. You should do any view configuration here and assign targets to elements such as switches.
        let configuration: ((UITableViewCell, Row) -> Void)?

        /// Called when this row is tapped. Optional.
        let handler: ((IndexPath) -> Void)?

        internal init(style: Style = .Value1, configuration: ((UITableViewCell, Row) -> Void)? = nil, handler: ((IndexPath) -> Void)? = nil) {
            self.style = style
            self.configuration = configuration
            self.handler = handler
        }

        /// Defines a cell identifier that will be used to initialise a cell class
        enum Style: String, CaseIterable {
            case Value1 = "Value1CellIdentifier"
            case Switch = "SwitchCellIdentifier"

            var cellType: UITableViewCell.Type {
                switch self {
                case .Value1:
                    return Value1TableViewCell.self
                case .Switch:
                    return SwitchTableViewCell.self
                }
            }
        }
    }

    // MARK: - Row Action Handling
    @objc
    func handlePinToTop(sender: UISwitch) {
        note.pinned = sender.isOn
        save()

        sender.accessibilityHint = note.pinned ?
            NSLocalizedString("Unpin note", comment: "Action to mark a note as unpinned") :
            NSLocalizedString("Pin note", comment: "Action to mark a note as pinned")
    }

    @objc
    func handleMarkdown(sender: UISwitch) {
        note.markdown = sender.isOn
        save()
        delegate?.didToggleMarkdown(toggle: sender, sender: self)

        sender.accessibilityHint = note.markdown ?
            NSLocalizedString("Disable Markdown formatting", comment: "Accessibility hint for disabling markdown mode") :
            NSLocalizedString("Enable Markdown formatting", comment: "Accessibility hint for enabling markdown mode")
    }

    func handleShare(from indexPath: IndexPath) {
        guard let activityVC = UIActivityViewController(note: note) else {
            return
        }
        SPTracker.trackEditorNoteContentShared()

        if UIDevice.sp_isPad() {
            activityVC.modalPresentationStyle = .popover

            let presentationController = activityVC.popoverPresentationController
            presentationController?.permittedArrowDirections = .any
            presentationController?.sourceRect = tableView.rectForRow(at: indexPath)
            presentationController?.sourceView = tableView
        }
        present(activityVC,
                animated: true,
                completion: nil)
    }

    func handleHistory() {
        delegate?.didTapHistory(sender: self)
    }

    @objc
    func handlePublish(sender: UISwitch) {
        if sender.isOn {
            SPTracker.trackEditorNotePublished()
        } else {
            SPTracker.trackEditorNoteUnpublished()
        }

        note.published = sender.isOn

        if (note.published && note.publishURL.isEmpty ||
            !note.published && !note.publishURL.isEmpty) {
            publishActivityIndicator.startAnimating()
        } else {
            publishActivityIndicator.stopAnimating()
        }

        save()

        sender.accessibilityHint = note.published ?
            NSLocalizedString("Unpublish note", comment: "Action which unpublishes a note") :
            NSLocalizedString("Publish note", comment: "Action which published a note to a web page")
    }

    func handleCopyLink(from indexPath: IndexPath) {
        guard !note.publishURL.isEmpty, let publishURL = URL(string: kSimplenotePublishURL + note.publishURL) else {
            return
        }

        SPTracker.trackEditorPublishedUrlPressed()

        let activityViewController = UIActivityViewController(activityItems: [publishURL],
                                                              applicationActivities: [SPActivitySafari()])
        if UIDevice.sp_isPad() {
            activityViewController.modalPresentationStyle = .popover

            let presentationController = activityViewController.popoverPresentationController
            presentationController?.permittedArrowDirections = .any
            presentationController?.sourceRect = tableView.rectForRow(at: indexPath)
            presentationController?.sourceView = tableView
        }
        present(activityViewController,
                animated: true,
                completion: nil)
    }

    func handleCollaborate(from indexPath: IndexPath) {
        SPTracker.trackEditorCollaboratorsAccessed()

        let collaboratorView = SPAddCollaboratorsViewController()
        collaboratorView.collaboratorDelegate = self
        collaboratorView.setup(withCollaborators: note.emailTagsArray as? [String])

        let navController = SPNavigationController(rootViewController: collaboratorView)
        navController.displaysBlurEffect = true

        if UIDevice.sp_isPad() {
            navController.modalPresentationStyle = .popover

            let presentationController = navController.popoverPresentationController
            presentationController?.permittedArrowDirections = .any
            presentationController?.sourceRect = tableView.rectForRow(at: indexPath)
            presentationController?.sourceView = tableView
        }
        present(navController,
                animated: true,
                completion: nil)
    }

    func handleMoveToTrash() {
        delegate?.didTapMoveToTrash(sender: self)
    }

    // MARK: - Navigation button handling
    @objc
    func handleDone(button: UIBarButtonItem) {
        dismiss(animated: true)
    }

    // MARK: - Note saving
    func save() {
        note.modificationDate = Date()
        note.createPreview()

        SPAppDelegate.shared().save()
        SPTracker.trackEditorNoteEdited()
        CSSearchableIndex.default().indexSearchableNote(note)
    }
}

// MARK: - Action protocol
//
/// A protocol to pass row actions to the parent view controller for handling
protocol NoteOptionsViewControllerDelegate: class {
    func didToggleMarkdown(toggle: UISwitch, sender: NoteOptionsViewController)
    func didTapHistory(sender: NoteOptionsViewController)
    func didTapCollaborators(sender: NoteOptionsViewController)
    func didTapMoveToTrash(sender: NoteOptionsViewController)
}

// MARK: - Collaboration handling
extension NoteOptionsViewController: SPCollaboratorDelegate {
    func collaboratorViewController(_ viewController: SPAddCollaboratorsViewController!, shouldAddCollaborator collaboratorEmail: String!) -> Bool {
        return !note.hasTag(collaboratorEmail)
    }

    func collaboratorViewController(_ viewController: SPAddCollaboratorsViewController!, didAddCollaborator collaboratorEmail: String!) {
        note.addTag(collaboratorEmail)
        save()
        SPTracker.trackEditorEmailTagAdded()
        tableView.reloadData()
    }

    func collaboratorViewController(_ viewController: SPAddCollaboratorsViewController!, didRemoveCollaborator collaboratorEmail: String!) {
        note.stripTag(collaboratorEmail)
        save()
        SPTracker.trackEditorEmailTagRemoved()
        tableView.reloadData()
    }
}
