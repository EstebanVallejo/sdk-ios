//
//  VaultViewController.swift
//  MercadoPagoSDK
//
//  Created by Matias Gualino on 7/1/15.
//  Copyright (c) 2015 com.mercadopago. All rights reserved.
//

import Foundation
import UIKit

public class VaultViewController : UIViewController, UITableViewDataSource, UITableViewDelegate {

    // ViewController parameters
    var publicKey: String?
    var merchantBaseUrl: String?
    var getCustomerUri: String?
    var merchantAccessToken: String?
    var amount : Double = 0
    var bundle : NSBundle? = MercadoPago.getBundle()
    
    public var callback : ((paymentMethod: PaymentMethod, tokenId: String?, issuerId: Int64?, installments: Int) -> Void)?
    
    // Input controls
    @IBOutlet weak private var tableview : UITableView!
    @IBOutlet weak private var emptyPaymentMethodCell : MPPaymentMethodEmptyTableViewCell!
    @IBOutlet weak private var paymentMethodCell : MPPaymentMethodTableViewCell!
    @IBOutlet weak private var installmentsCell : MPInstallmentsTableViewCell!
    @IBOutlet weak private var securityCodeCell : MPSecurityCodeTableViewCell!
    public var loadingView : UILoadingView!
    
    // Current values
    public var selectedCard : Card? = nil
    public var selectedPayerCost : PayerCost? = nil
    public var selectedCardToken : CardToken? = nil
    public var selectedPaymentMethod : PaymentMethod? = nil
    public var selectedIssuer : Issuer? = nil
    public var cards : [Card]?
    public var payerCosts : [PayerCost]?

    public var securityCodeRequired : Bool = true
    public var securityCodeLength : Int = 0
    public var bin : String?
    
    public var supportedPaymentTypes : [String]?
    
    init(merchantPublicKey: String, merchantBaseUrl: String?, merchantGetCustomerUri: String?, merchantAccessToken: String?, amount: Double, supportedPaymentTypes: [String], callback: (paymentMethod: PaymentMethod, tokenId: String?, issuerId: Int64?, installments: Int) -> Void) {
        super.init(nibName: "VaultViewController", bundle: bundle)
        self.merchantBaseUrl = merchantBaseUrl
        self.getCustomerUri = merchantGetCustomerUri
        self.merchantAccessToken = merchantAccessToken
        self.publicKey = merchantPublicKey
        self.amount = amount
        self.callback = callback
        self.supportedPaymentTypes = supportedPaymentTypes
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        var tableSelection : NSIndexPath? = self.tableview.indexPathForSelectedRow()
        if tableSelection != nil {
            self.tableview.deselectRowAtIndexPath(tableSelection!, animated: false)
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Pagar".localized
        
        self.loadingView = UILoadingView(frame: MercadoPago.screenBoundsFixedToPortraitOrientation(), text: "Cargando...".localized)
        
        declareAndInitCells()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Continuar".localized, style: UIBarButtonItemStyle.Plain, target: self, action: "submitForm")
        self.navigationItem.rightBarButtonItem?.enabled = false
        
        self.tableview.delegate = self
        self.tableview.dataSource = self
        
        if self.merchantBaseUrl != nil && self.getCustomerUri != nil {
        
            self.view.addSubview(self.loadingView)
            
            MerchantServer.getCustomer(self.merchantBaseUrl!, merchantGetCustomerUri: self.getCustomerUri!, merchantAccessToken: self.merchantAccessToken!, success: { (customer: Customer) -> Void in
                self.cards = customer.cards
                self.loadingView.removeFromSuperview()
                self.tableview.reloadData()
                }, failure: { (error: NSError?) -> Void in
                    MercadoPago.showAlertViewWithError(error, nav: self.navigationController)
            })
        } else {
            self.tableview.reloadData()
        }

    }
	
	public override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "willShowKeyboard:", name: UIKeyboardWillShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "willHideKeyboard:", name: UIKeyboardWillHideNotification, object: nil)
	}
	
	public override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func willHideKeyboard(notification: NSNotification) {
		// resize content insets.
		let contentInsets = UIEdgeInsetsMake(64, 0.0, 0.0, 0)
		self.tableview.contentInset = contentInsets
		self.tableview.scrollIndicatorInsets = contentInsets
		self.scrollToRow(NSIndexPath(forRow: 0, inSection: 0))
	}
	
	func willShowKeyboard(notification: NSNotification) {
		let s:NSValue? = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)
		var keyboardBounds :CGRect = s!.CGRectValue()
		
		// resize content insets.
		let contentInsets = UIEdgeInsetsMake(64, 0.0, keyboardBounds.size.height, 0)
		self.tableview.contentInset = contentInsets
		self.tableview.scrollIndicatorInsets = contentInsets

		let securityIndexPath = self.tableview.indexPathForCell(self.securityCodeCell)
		if securityIndexPath != nil {
			self.scrollToRow(securityIndexPath!)
		}
	}
	
	public func scrollToRow(indexPath: NSIndexPath) {
		self.tableview.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
	}
    
    public func declareAndInitCells() {
        var paymentMethodNib = UINib(nibName: "MPPaymentMethodTableViewCell", bundle: self.bundle)
        self.tableview.registerNib(paymentMethodNib, forCellReuseIdentifier: "paymentMethodCell")
        self.paymentMethodCell = self.tableview.dequeueReusableCellWithIdentifier("paymentMethodCell") as! MPPaymentMethodTableViewCell
        
        var emptyPaymentMethodNib = UINib(nibName: "MPPaymentMethodEmptyTableViewCell", bundle: self.bundle)
        self.tableview.registerNib(emptyPaymentMethodNib, forCellReuseIdentifier: "emptyPaymentMethodCell")
        self.emptyPaymentMethodCell = self.tableview.dequeueReusableCellWithIdentifier("emptyPaymentMethodCell") as! MPPaymentMethodEmptyTableViewCell
        
        var securityCodeNib = UINib(nibName: "MPSecurityCodeTableViewCell", bundle: self.bundle)
        self.tableview.registerNib(securityCodeNib, forCellReuseIdentifier: "securityCodeCell")
        self.securityCodeCell = self.tableview.dequeueReusableCellWithIdentifier("securityCodeCell")as! MPSecurityCodeTableViewCell
        
        var installmentsNib = UINib(nibName: "MPInstallmentsTableViewCell", bundle: self.bundle)
        self.tableview.registerNib(installmentsNib, forCellReuseIdentifier: "installmentsCell")
        self.installmentsCell = self.tableview.dequeueReusableCellWithIdentifier("installmentsCell") as! MPInstallmentsTableViewCell
    }
 
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if self.selectedCard == nil && self.selectedCardToken == nil {
			if (self.selectedPaymentMethod != nil && !MercadoPago.isCardPaymentType(self.selectedPaymentMethod!.paymentTypeId)) {
				self.navigationItem.rightBarButtonItem?.enabled = true
			}
			return 1
		}
        else if self.selectedPayerCost == nil {
            return 2
        } else if !securityCodeRequired {
            self.navigationItem.rightBarButtonItem?.enabled = true
            return 2
        }
        self.navigationItem.rightBarButtonItem?.enabled = true
        return 3
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            if self.selectedCard == nil && self.selectedPaymentMethod == nil {
                self.emptyPaymentMethodCell = self.tableview.dequeueReusableCellWithIdentifier("emptyPaymentMethodCell") as! MPPaymentMethodEmptyTableViewCell
                return self.emptyPaymentMethodCell
            } else {
                self.paymentMethodCell = self.tableview.dequeueReusableCellWithIdentifier("paymentMethodCell") as! MPPaymentMethodTableViewCell
                if !MercadoPago.isCardPaymentType(self.selectedPaymentMethod!.paymentTypeId) {
                    self.paymentMethodCell.fillWithPaymentMethod(self.selectedPaymentMethod!)
                }
                else if self.selectedCardToken != nil {
                    self.paymentMethodCell.fillWithCardTokenAndPaymentMethod(self.selectedCardToken, paymentMethod: self.selectedPaymentMethod!)
                } else {
                    self.paymentMethodCell.fillWithCard(self.selectedCard)
                }
                return self.paymentMethodCell
            }
        } else if indexPath.row == 1 {
            self.installmentsCell = self.tableview.dequeueReusableCellWithIdentifier("installmentsCell") as! MPInstallmentsTableViewCell
            self.installmentsCell.fillWithPayerCost(self.selectedPayerCost, amount: self.amount)
            return self.installmentsCell
        } else if indexPath.row == 2 {
            self.securityCodeCell = self.tableview.dequeueReusableCellWithIdentifier("securityCodeCell") as! MPSecurityCodeTableViewCell
			self.securityCodeCell.height = 143
            self.securityCodeCell.fillWithPaymentMethod(self.selectedPaymentMethod!)
            return self.securityCodeCell
        }
        return UITableViewCell()
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (indexPath.row == 2) {
			return self.securityCodeCell != nil ? self.securityCodeCell.getHeight() : 143
        }
        return 65
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == 0 {
            let paymentMethodsViewController = getPaymentMethodsViewController()

            if self.cards != nil && self.cards!.count > 0 {
                    let customerPaymentMethodsViewController = MercadoPago.startCustomerCardsViewController(self.cards!, callback: {(selectedCard: Card?) -> Void in
                        if selectedCard != nil {
                            self.selectedCard = selectedCard
                            self.selectedPaymentMethod = self.selectedCard?.paymentMethod
                            self.selectedIssuer = self.selectedCard?.issuer
                            self.bin = self.selectedCard?.firstSixDigits
                            self.securityCodeLength = self.selectedCard!.securityCode!.length
                            self.securityCodeRequired = self.securityCodeLength > 0
                            self.loadPayerCosts()
                            self.navigationController!.popViewControllerAnimated(true)
                        } else {
                            self.showViewController(paymentMethodsViewController, sender: self)
                        }
                    })
                    showViewController(customerPaymentMethodsViewController, sender: self)
            } else {
                showViewController(paymentMethodsViewController, sender: self)
            }
        } else if indexPath.row == 1 {
            self.showViewController(MercadoPago.startInstallmentsViewController(payerCosts!, amount: amount, callback: { (payerCost: PayerCost?) -> Void in
					self.selectedPayerCost = payerCost
					self.tableview.reloadData()
					self.navigationController!.popToViewController(self, animated: true)
                }), sender: self)
        }
    }
    
    public func loadPayerCosts() {
        self.view.addSubview(self.loadingView)
        let mercadoPago : MercadoPago = MercadoPago(publicKey: self.publicKey!)
        mercadoPago.getInstallments(self.bin!, amount: self.amount, issuerId: self.selectedIssuer?._id, paymentTypeId: self.selectedPaymentMethod!.paymentTypeId!, success: {(installments: [Installment]?) -> Void in
            if installments != nil {
                self.payerCosts = installments![0].payerCosts
                self.tableview.reloadData()
                self.loadingView.removeFromSuperview()
            }
            }, failure: { (error: NSError?) -> Void in
                MercadoPago.showAlertViewWithError(error, nav: self.navigationController)
				self.navigationController?.popToRootViewControllerAnimated(true)
        })
    }
    
    public func submitForm() {
		
		self.securityCodeCell.securityCodeTextField.resignFirstResponder()
		
        let mercadoPago : MercadoPago = MercadoPago(publicKey: self.publicKey!)
        
        var canContinue = true
        if self.securityCodeRequired {
            let securityCode = self.securityCodeCell.getSecurityCode()
            if String.isNullOrEmpty(securityCode) {
                self.securityCodeCell.setError("invalid_field".localized)
                canContinue = false
            } else if count(securityCode) != securityCodeLength {
                self.securityCodeCell.setError(("invalid_cvv_length".localized as NSString).stringByReplacingOccurrencesOfString("%1$s", withString: "\(securityCodeLength)"))
                canContinue = false
            }
        }
        
        if !canContinue {
            self.tableview.reloadData()
        } else {
            // Create token
            if selectedCard != nil {
                
                let securityCode = self.securityCodeRequired ? securityCodeCell.securityCodeTextField.text : nil
                
                let savedCardToken : SavedCardToken = SavedCardToken(cardId: String(format:"%ld",selectedCard!._id), securityCode: securityCode, securityCodeRequired: self.securityCodeRequired)
                
                if savedCardToken.validate() {
                    // Send card id to get token id
                    self.view.addSubview(self.loadingView)
                    mercadoPago.createToken(savedCardToken, success: {(token: Token?) -> Void in
                        var tokenId : String? = nil
                        if token != nil {
                            tokenId = token!._id
                        }
						
						var installments = self.selectedPayerCost == nil ? 0 : self.selectedPayerCost!.installments
						
                        self.callback!(paymentMethod: self.selectedPaymentMethod!, tokenId: tokenId, issuerId: self.selectedIssuer?._id, installments: installments)
                        }, failure: { (error: NSError?) -> Void in
                            MercadoPago.showAlertViewWithError(error, nav: self.navigationController)
                    })
                } else {
                    println("Invalid data")
                    return
                }
            } else {
                self.selectedCardToken!.securityCode = self.securityCodeCell.securityCodeTextField.text
                self.view.addSubview(self.loadingView)
                mercadoPago.createNewCardToken(self.selectedCardToken!, success: {(token: Token?) -> Void in
                    var tokenId : String? = nil
                    if token != nil {
                        tokenId = token!._id
                    }
					
					var installments = self.selectedPayerCost == nil ? 0 : self.selectedPayerCost!.installments
					
                    self.callback!(paymentMethod: self.selectedPaymentMethod!, tokenId: tokenId, issuerId: self.selectedIssuer?._id, installments: installments)
                    }, failure: { (error: NSError?) -> Void in
                        MercadoPago.showAlertViewWithError(error, nav: self.navigationController)
                })
            }
        }
    }
    
    func getPaymentMethodsViewController() -> PaymentMethodsViewController {
        return MercadoPago.startPaymentMethodsViewController(self.publicKey!, supportedPaymentTypes: self.supportedPaymentTypes!, callback: { (paymentMethod : PaymentMethod) -> Void in
            self.selectedPaymentMethod = paymentMethod
            if MercadoPago.isCardPaymentType(paymentMethod.paymentTypeId) {
                self.selectedCard = nil
                if paymentMethod.settings != nil && paymentMethod.settings.count > 0 {
                    self.securityCodeLength = paymentMethod.settings![0].securityCode!.length
                    self.securityCodeRequired = self.securityCodeLength != 0
                }
                
                let newCardViewController = MercadoPago.startNewCardViewController(MercadoPago.PUBLIC_KEY, key: self.publicKey!, paymentMethod: self.selectedPaymentMethod!, requireSecurityCode: self.securityCodeRequired, callback: { (cardToken: CardToken) -> Void in
                    self.selectedCardToken = cardToken
                    self.bin = self.selectedCardToken?.getBin()
                    self.loadPayerCosts()
                    self.navigationController!.popToViewController(self, animated: true)
                })
                
                if self.selectedPaymentMethod!.isIssuerRequired() {
                    let issuerViewController = MercadoPago.startIssuersViewController(self.publicKey!, paymentMethod: self.selectedPaymentMethod!,
                        callback: { (issuer: Issuer) -> Void in
                            self.selectedIssuer = issuer
							self.showViewController(newCardViewController, sender: self)
                    })
                    self.showViewController(issuerViewController, sender: self)
                } else {
                    self.showViewController(newCardViewController, sender: self)
                }
            } else {
                self.tableview.reloadData()
                self.navigationController!.popToViewController(self, animated: true)
            }
        })
    }
    
}