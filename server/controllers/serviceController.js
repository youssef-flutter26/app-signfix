const database = require('../database');
const { businessId } = require('../utils/ids');

async function list(req, res, next) {
  try {
    const data = await database.listServices(req.user, req.query);
    return res.json({
      data,
      page: Number(req.query.page || 1),
      total: data.length,
    });
  } catch (error) {
    return next(error);
  }
}

async function create(req, res, next) {
  try {
    const canSelectPriority =
      process.env.CUSTOMER_CAN_SELECT_SERVICE_PRIORITY === 'true';
    const priority =
      req.user.role === 'customer' && !canSelectPriority
        ? req.body.category === 'Emergency'
          ? 'emergency'
          : 'normal'
        : req.body.priority;

    const result = await database.createService(
      req.user,
      { ...req.body, priority },
      businessId('SB-SRV'),
    );

    return res.status(201).json(result);
  } catch (error) {
    return next(error);
  }
}

async function update(req, res, next) {
  try {
    return res.json(await database.updateService(req.params.id, req.body, req.user));
  } catch (error) {
    return next(error);
  }
}

module.exports = { list, create, update };
