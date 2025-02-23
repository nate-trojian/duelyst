express = require 'express'
moment = require 'moment'
UsersModule = require '../../../lib/data_access/users'
InventoryModule = require '../../../lib/data_access/inventory'
ShopModule = require '../../../lib/data_access/shop'
knex = require '../../../lib/data_access/knex'
DataAccessHelpers = require '../../../lib/data_access/helpers'
Logger = require '../../../../app/common/logger.coffee'
Errors = require '../../../lib/custom_errors'
t = require 'tcomb-validation'
validators = require '../../../validators'

# TODO: remove these 2
PremiumShopData = require 'app/data/premium_shop.json'
ShopData = require('app/data/shop.json')

router = express.Router()

router.post "/premium_purchase", (req, res, next) ->
	result = t.validate(req.body, validators.premiumPurchaseInput)
	if not result.isValid()
		return res.status(400).json(result.errors)

	user_id = req.user.d.id
	product_sku = result.value.product_sku
	bn_token = result.value.bn_token
	sale_id = result.value.sale_id

	ShopModule.purchaseProductWithPremiumCurrency(user_id,product_sku,bn_token,sale_id)
	.then ()->
		Logger.module("API").debug "User #{user_id.blue} purchased #{product_sku}".cyan
		res.status(200).json({})
	.catch (error)->
		Logger.module("API").error "ERROR Processing Purchase #{product_sku} by #{user_id.blue}".red
		if error.raw?.type == "card_error" or error.raw?.type == "invalid_request_error"
			Logger.module("API").error "ERROR is safe to print for user #{user_id.blue}".red
			res.status(500).json({error: error.message})
		else
			next(error)

router.post "/customer", (req, res, next) ->
	result = t.validate(req.body, validators.shopInput)
	if not result.isValid()
		return res.status(400).json(result.errors)

	user_id = req.user.d.id
	card_token = result.value.card_token
	card_last_four_digits = result.value.last_four_digits

	Logger.module("API").debug "Updating Credit Card and Customer data for user #{user_id.blue}".magenta
	ShopModule.updateUserCreditCardToken(user_id,card_token,card_last_four_digits)
	.then (customerData) ->
		Logger.module("API").debug "Updated Credit Card and Customer data for user #{user_id.blue}".cyan
		res.status(200).json({})
	.catch (error) ->
		Logger.module("API").error "ERROR Updating Credit Card and Customer data for user #{user_id.blue}".red
		if error.raw?.type == "card_error" or error.raw?.type == "invalid_request_error"
			Logger.module("API").error "ERROR is safe to print for user #{user_id.blue}".red
			res.status(500).json({error: error.message})
		else
			next(error)

router.delete "/customer", (req, res, next) ->
	user_id = req.user.d.id
	ShopModule.deleteUserCreditCardToken(user_id)
	.then (customerData) ->
		Logger.module("API").debug "Deleted Credit Card and Customer data for user #{user_id.blue}".cyan
		res.status(200).json({})
	.catch (error) ->
		Logger.module("API").error "ERROR Deleting Credit Card and Customer data for user #{user_id.blue}".red
		if error.raw?.type == "card_error" or error.raw?.type == "invalid_request_error"
			Logger.module("API").error "ERROR is safe to print for user #{user_id.blue}".red
			res.status(500).json({error: error.message})
		else
			next(error)

# TODO: Remove
router.get "/premium_pack_products", (req, res, next) ->
	user_id = req.user.d.id

	return Promise.resolve(PremiumShopData)
	.then (premiumPackData) ->
		res.status(200).json(premiumPackData)
	.catch (error) ->
		res.status(500).json({error: error.message})

# Returns array of all expired shop sales
router.get "/sales", (req, res, next) ->
	Logger.module("API").debug "Retrieving unexpired shop sales".magenta

	MOMENT_NOW_UTC = moment.utc()

	# Retrieves all unexpired sales, returns sales that havent started yet
	return knex("shop_sales").select("sale_id","sku","sale_price","sale_starts_at","sale_ends_at").where("sale_ends_at",'>',MOMENT_NOW_UTC.toDate()).andWhere("disabled",'=',false)
	.then (shopSalesRows) ->
		res.status(200).json(shopSalesRows)
	.catch (error) ->
		res.status(500).json({error: error.message})

module.exports = router
